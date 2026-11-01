# frozen_string_literal: true

# == Schema Information
#
# Table name: payroll_positions
#
#  id                          :bigint           not null, primary key
#  aasm_state                  :string           not null
#  combine_contract_attachment :boolean          default(TRUE), not null
#  currency                    :string           default("USD"), not null
#  description                 :text             not null
#  end_date                    :date             not null
#  onboarded_at                :datetime
#  onboarding_at               :datetime
#  rate_cents                  :integer          default(0), not null
#  rate_unit                   :string           default("hour"), not null
#  rejected_at                 :datetime
#  start_date                  :date             not null
#  terminated_at               :datetime
#  title                       :text             not null
#  created_at                  :datetime         not null
#  updated_at                  :datetime         not null
#  manager_id                  :bigint
#  payee_id                    :bigint           not null
#  renewal_of_id               :bigint
#
# Indexes
#
#  index_payroll_positions_on_manager_id     (manager_id)
#  index_payroll_positions_on_payee_id       (payee_id)
#  index_payroll_positions_on_renewal_of_id  (renewal_of_id)
#
# Foreign Keys
#
#  fk_rails_...  (payee_id => payees.id)
#
module Payroll
  class Position < ApplicationRecord
    include AASM
    include Contractable
    include PgSearch::Model
    include Hashid::Rails

    has_paper_trail

    belongs_to :payee
    belongs_to :manager, optional: true, class_name: "User"
    belongs_to :renewal_of, optional: true, class_name: "Payroll::Position", inverse_of: :renewals
    has_many :renewals, class_name: "Payroll::Position", foreign_key: :renewal_of_id, inverse_of: :renewal_of, dependent: :nullify

    delegate :display_name, to: :payee, prefix: true

    # Renewals that were rejected, or terminated before they were signed, never
    # took effect, so they don't count as part of a contractor's chain.
    scope :live, -> { where(aasm_state: %i[under_review onboarding onboarded expired]).or(where(aasm_state: :terminated).where.not(onboarded_at: nil)) }

    # Renewals that have been signed and have started, taking over from the
    # contract they renew.
    scope :started_renewals, -> { where.not(renewal_of_id: nil).where.not(onboarded_at: nil).where(start_date: ..Date.current) }

    # Signed renewals still waiting for the contract they renew to end.
    scope :upcoming_renewals, -> { where.not(renewal_of_id: nil).where.not(onboarded_at: nil).where(start_date: Date.current.tomorrow..) }

    # Each contractor's chain of renewals is listed as a single position: the
    # latest one that has started, or the first while it's still onboarding.
    scope :current, -> {
      where(renewal_of_id: nil).or(started_renewals).where.not(id: started_renewals.select(:renewal_of_id))
    }

    pg_search_scope :search_recipient, associated_against: { payee: [:display_name, :email] }, using: { tsearch: { prefix: true, dictionary: "english" } }
    # For viewers who can't see the payee's email (see `EventsController#contractors`).
    pg_search_scope :public_search_recipient, associated_against: { payee: [:display_name] }, using: { tsearch: { prefix: true, dictionary: "english" } }

    has_many :invoices, class_name: "Payroll::Invoice", foreign_key: "payroll_position_id", inverse_of: :payroll_position, dependent: :destroy
    has_many :payments, through: :invoices
    has_one :event, through: :payee
    has_one :contract_event, through: :payee, source: :event # a requirement of Contractable
    has_one :contract, ->{ where.not(aasm_state: :voided) }, inverse_of: :contractable, as: :contractable

    has_one_attached :file
    validates :file, size: { less_than_or_equal_to: 25.megabytes }, content_type: [:pdf], if: -> { attachment_changes["file"].present? }

    monetize :rate_cents, with_model_currency: :currency

    FIXED_RATE_UNIT = "contract"

    normalizes :rate_unit, with: ->(unit) { unit&.strip&.downcase&.singularize }

    def fixed_rate?
      rate_unit == FIXED_RATE_UNIT
    end

    def rate_suffix
      case rate_unit
      when "hour" then "/hr"
      when FIXED_RATE_UNIT then " (fixed)"
      else " per #{rate_unit}"
      end
    end

    def rate_label
      "#{rate.format}#{rate_suffix}"
    end

    MAX_DURATION = 1.year
    MAX_START_LEAD_TIME = 6.months

    CONTRACTOR_ONBOARDING_STEPS = %i[tax_form contractor_signature payout_method].freeze

    ONBOARDING_REMINDER_DAYS = [1, 2, 7, 14].freeze
    ONBOARDING_REMINDER_INTERVAL_DAYS = 14

    after_create_commit do
      Payroll::Position::ExpireJob.set(wait_until: end_date.end_of_day).perform_later(self)
    end

    validates :title, :description, :start_date, :end_date, presence: true
    validates :rate_unit, presence: true, length: { maximum: 30 }
    validates :currency, inclusion: { in: Money::Currency.all.map(&:iso_code) }
    validate :end_date_after_start_date
    validate :start_date_within_set_lead_time
    validate :duration_within_set_max
    validate :manager_is_event_manager
    validate :renewal_of_is_renewable, on: :create, if: :renewal_of

    aasm timestamps: true do
      state :under_review, initial: true
      state :onboarding
      state :onboarded
      state :expired
      state :rejected
      state :terminated

      event :mark_onboarding do
        transitions from: :under_review, to: :onboarding
      end

      event :mark_under_review do
        transitions from: :onboarding, to: :under_review
      end

      event :mark_rejected do
        transitions from: [:under_review, :onboarding], to: :rejected
      end

      event :mark_onboarded do
        transitions from: :onboarding, to: :onboarded, guard: :onboarding_complete?
        after do
          Payroll::PositionMailer.with(position: self).onboarded.deliver_later
        end
      end

      event :mark_expired do
        transitions from: :onboarded, to: :expired
      end

      event :mark_terminated do
        transitions from: [:under_review, :onboarding, :onboarded], to: :terminated

        after do |options = {}|
          # If it's still under review, we haven't sent any emails to the contractor yet,
          # so we won't tell them that they've been "terminated"
          Payroll::PositionMailer.with(position: self).terminated.deliver_later unless aasm.from_state == :under_review || options[:notify] == false
        end
      end
    end

    def status
      case aasm_state.to_sym
      when :onboarded
        upcoming_renewal? ? :upcoming : :active
      when :under_review, :onboarding
        :onboarding
      when :expired
        :completed
      else
        aasm_state.to_sym
      end
    end

    def status_text
      status.to_s.humanize
    end

    def status_color
      case status
      when :active then "success"
      when :onboarding, :upcoming then "info"
      else "muted"
      end
    end

    # Renders the contract window like "Jan 1 – Jun 30, 2026", collapsing within
    # a single month ("Apr 1–28, 2026") or spanning years
    # ("Dec 1, 2025 – Feb 28, 2026") when needed.
    def period_label
      return if start_date.nil?
      return start_date.strftime("%b %-d, %Y") if end_date.nil? || start_date == end_date

      if start_date.year != end_date.year
        "#{start_date.strftime("%b %-d, %Y")} – #{end_date.strftime("%b %-d, %Y")}"
      elsif start_date.month != end_date.month
        "#{start_date.strftime("%b %-d")} – #{end_date.strftime("%b %-d, %Y")}"
      else
        "#{start_date.strftime("%b %-d")}–#{end_date.strftime("%-d, %Y")}"
      end
    end

    # The live renewal of this position, if one has been started.
    def renewal
      renewals.live.order(:id).last
    end

    # A renewal that hasn't been signed by everyone yet. Its predecessor is
    # still the contractor's contract of record until it is.
    def unsigned_renewal?
      renewal_of_id.present? && onboarded_at.nil?
    end

    # A signed renewal waiting for the contract it renews to end.
    def upcoming_renewal?
      onboarded? && renewal_of_id.present? && start_date > Date.current
    end

    # A signed renewal only takes invoices once it has started.
    def accepting_invoices?
      onboarded? && !upcoming_renewal?
    end

    # Positions still being onboarded are changed by editing them instead. A
    # renewal has to start within the usual lead time, so a contract can't be
    # renewed until it's that close to ending. An archived payee can't be
    # contracted again, just like when inviting a contractor.
    def renewable?
      (onboarded? || expired?) && !payee.archived? && renewal.nil? && renewal_start_date <= MAX_START_LEAD_TIME.from_now.to_date
    end

    # A renewal picks up the day after this contract ends, or today if it has
    # already lapsed.
    def renewal_start_date
      [end_date + 1.day, Date.current].max
    end

    # Drafts a renewal carrying over this position's terms, which the
    # organizer can change before it's sent for signing.
    def build_renewal
      start_date = renewal_start_date
      duration = [(end_date - self.start_date).to_i.days, MAX_DURATION].min

      renewals.build(
        payee:,
        manager:,
        title:,
        description:,
        rate_cents:,
        rate_unit:,
        currency:,
        combine_contract_attachment:,
        start_date:,
        end_date: start_date + duration
      ).tap do |renewal|
        # Blobs are only purged once nothing is attached to them, so sharing
        # one is safe even if the renewal's attachment is later replaced.
        renewal.file.attach(file.blob) if file.attached?
      end
    end

    # Every position in this contractor's chain of renewals, oldest first.
    def renewal_chain
      chain = [self]
      chain.unshift(chain.first.renewal_of) while chain.first.renewal_of
      while (successor = chain.last.renewal)
        chain << successor
      end
      chain
    end

    def chain_invoices
      Payroll::Invoice.where(payroll_position: renewal_chain)
    end

    # Terminating a renewal, signed or not, leaves the contract it renews in
    # place. Terminating a contract also ends any renewal of it, so a renewal
    # waiting to start doesn't outlive it, though the contractor only needs to
    # hear about it once.
    def terminate!
      notified = false

      transaction do
        positions_to_terminate.each do |position|
          notify = !notified && !position.under_review?
          position.mark_terminated!(notify:)
          notified ||= notify
        end
      end
    end

    def terminatable?
      positions_to_terminate.any?
    end

    # The steps a contractor must complete before payments can be sent, each as
    # { label:, complete: }. Rendered in the contractor show modal.
    def onboarding_checklist
      legal_entity = payee.legal_entity

      [
        {
          key: :organizer_signature,
          owner: :organizer,
          label: "Sign the contract",
          hint: "Starts the onboarding process",
          complete: contract_signed_by?(:organizer)
        },
        {
          key: :hcb_review,
          owner: :hcb,
          label: "HCB team review",
          hint: "The contractor is emailed once HCB signs",
          complete: !under_review? && !rejected?
        },
        {
          key: :tax_form,
          owner: :contractor,
          label: "Submit tax information",
          hint: "Needed before contractor signs",
          complete: legal_entity&.completed_tax_form? || false
        },
        {
          key: :contractor_signature,
          owner: :contractor,
          label: "Contractor signs",
          hint: "Makes the agreement official",
          complete: contract_signed_by?(:contractor)
        },
        {
          key: :payout_method,
          owner: :contractor,
          label: "Add a payout method",
          hint: "Can be done at any time",
          complete: legal_entity&.default_payout_method.present?
        },
      ]
    end

    # True once every onboarding step is done. Used both as the AASM guard for
    # +mark_onboarded+ and to decide whether to advance the position.
    def onboarding_complete?
      onboarding_checklist.all? { |step| step[:complete] }
    end

    # The next step the contractor still needs to complete, or nil once done.
    def next_onboarding_step
      onboarding_checklist.find { |step| !step[:complete] }
    end

    def contractor_onboarding_incomplete?
      onboarding_checklist.any? do |step|
        CONTRACTOR_ONBOARDING_STEPS.include?(step[:key]) && !step[:complete]
      end
    end

    def onboarding_reminder_days
      days_remaining = (end_date - Date.current).to_i
      days = ONBOARDING_REMINDER_DAYS.dup
      days << days.last + ONBOARDING_REMINDER_INTERVAL_DAYS while days.last + ONBOARDING_REMINDER_INTERVAL_DAYS < days_remaining
      days.select { |day| day < days_remaining }
    end

    def tax_info_needed?
      !payee.legal_entity&.payable?
    end

    def payout_method_needed?
      payee.legal_entity&.default_payout_method.blank?
    end

    def refresh_onboarding_state!
      mark_onboarded! if onboarding? && may_mark_onboarded?
    end

    def on_contract_signed(contract)
      refresh_onboarding_state!
    end

    def on_contract_party_signed(party)
      refresh_onboarding_state!

      # The contractor is only invited to sign once HCB has signed
      if party.hcb?
        # HCB signing is the "reviewed by HCB operations" step, so begin onboarding.
        mark_onboarding! if may_mark_onboarding?

        contractor = party.contract.party(:contractor)
        return if contractor.nil? || contractor.signed?

        notify_contractor_of_onboarding(contractor)
        schedule_onboarding_reminders
      end
    end

    def send_contract(organizer_user: nil, cosigner_email: nil, reissue_messages: {}, reissue_of: nil, **options)
      contract = nil
      organizer_user ||= reissue_of&.party(:organizer)&.user
      raise ArgumentError, "an organizer is required to send a payroll contract" if organizer_user.nil?

      ActiveRecord::Base.transaction do
        contract = Contract::PayrollPosition.create!(
          contractable: self,
          include_videos: false,
          external_template_id: Contract::PayrollPosition::DOCUSEAL_TEMPLATE_ID,
          prefills: {
            "payee_name"        => payee.display_name,
            "title"             => title,
            "description"       => description,
            "rate"              => rate_label,
            "start_date"        => start_date.to_fs(:long),
            "end_date"          => end_date.to_fs(:long),
            "documents"         => (file.attached? ? [{ "name" => file.blob.filename.to_s, "file" => Rails.application.routes.url_helpers.rails_blob_url(file) }] : nil),
            "combine_documents" => combine_contract_attachment
          }.compact,
          reissue_of:
        )
        contract.parties.create!(user: organizer_user, role: :organizer)
        contract.parties.create!(user: contractor_user, external_email: payee.email, role: :contractor)
      end

      begin
        contract.send!(reissue_messages:)
      rescue Faraday::Error
        # The contract row is already committed; void it (skipping the
        # on_contract_voided callback) so it doesn't linger as a broken,
        # un-sendable "pending" contract blocking future retries.
        contract.mark_voided!(reissuing: true) if contract.may_mark_voided?
        raise
      end

      contract
    end


    def on_contract_voided(contract)
      mark_rejected! if may_mark_rejected?
    end

    def contract_redirect_path
      Rails.application.routes.url_helpers.my_payroll_path
    end

    def contractable_link_label
      "contractor position"
    end

    def contractable_link_path
      Rails.application.routes.url_helpers.event_payroll_position_path(event, self)
    end

    # The contractor isn't emailed when the contract is sent; they're notified
    # only once HCB signs
    def contract_notify_when_sent
      false
    end

    # Contractor reminders are scheduled once HCB signs instead
    def contract_remind_when_reissued
      false
    end

    def contract_notify_hcb?
      false
    end

    def notify_mailer_for(party)
      return super unless party.contractor?

      Payroll::PositionMailer.with(position: self, party:).onboarding.deliver_later
    end

    def notify_contractor_of_onboarding(contractor)
      contractor.notify
    rescue => e
      Rails.error.report(e, context: { payroll_position_id: id })
    end

    private

    # This position and any renewals of it that can still be terminated.
    def positions_to_terminate
      renewal_chain.drop_while { |position| position != self }.select(&:may_mark_terminated?)
    end

    def schedule_onboarding_reminders
      onboarding_reminder_days.each do |days|
        Payroll::Position::OnboardingReminderJob.set(wait: days.days).perform_later(self)
      end
    end

    def contract_signed_by?(role)
      contracts.not_voided.any? { |contract| contract.party(role)&.signed? }
    end

    def contractor_user
      User.find_by(email: payee.email)
    end

    def end_date_after_start_date
      return if start_date.blank? || end_date.blank?

      errors.add(:end_date, "must be after the start date") if end_date <= start_date
    end

    def start_date_within_set_lead_time
      return if start_date.blank?

      errors.add(:start_date, "cannot be more than 6 months in the future") if start_date > MAX_START_LEAD_TIME.from_now.to_date
    end

    def duration_within_set_max
      return if start_date.blank? || end_date.blank?

      errors.add(:end_date, "cannot be more than 1 year after the start date") if end_date > start_date + MAX_DURATION
    end

    def renewal_of_is_renewable
      errors.add(:base, "This contract can't be renewed") unless renewal_of.renewable?
      errors.add(:start_date, "must be after the previous contract ends") if start_date.present? && start_date <= renewal_of.end_date
    end

    def manager_is_event_manager
      return if manager.nil?

      op = event.organizer_positions.where(user_id: manager.id).last
      if op.nil? || op.role != "manager"
        errors.add(:manager, "must be a manager of the event this position is for")
      end
    end

  end
end
