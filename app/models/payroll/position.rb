# frozen_string_literal: true

# == Schema Information
#
# Table name: payroll_positions
#
#  id            :bigint           not null, primary key
#  aasm_state    :string           not null
#  currency      :string           default("USD"), not null
#  description   :text             not null
#  end_date      :date             not null
#  onboarded_at  :datetime
#  onboarding_at :datetime
#  rate_cents    :integer          default(0), not null
#  rejected_at   :datetime
#  start_date    :date             not null
#  terminated_at :datetime
#  title         :text             not null
#  created_at    :datetime         not null
#  updated_at    :datetime         not null
#  payee_id      :bigint           not null
#
# Indexes
#
#  index_payroll_positions_on_payee_id  (payee_id)
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

    delegate :display_name, to: :payee, prefix: true

    pg_search_scope :search_recipient, associated_against: { payee: [:display_name, :email] }, using: { tsearch: { prefix: true, dictionary: "english" } }

    has_many :invoices, class_name: "Payroll::Invoice", foreign_key: "payroll_position_id", inverse_of: :payroll_position, dependent: :destroy
    has_one :event, through: :payee
    has_one :contract_event, through: :payee, source: :event # a requirement of Contractable
    has_one :contract, ->{ where.not(aasm_state: :voided) }, inverse_of: :contractable, as: :contractable

    has_one_attached :file
    validates :file, size: { less_than_or_equal_to: 25.megabytes }, content_type: [:pdf], if: -> { attachment_changes["file"].present? }

    monetize :rate_cents, with_model_currency: :currency

    MAX_DURATION = 1.year
    MAX_START_LEAD_TIME = 6.months

    after_create_commit do
      Payroll::Position::ExpireJob.set(wait_until: end_date.end_of_day).perform_later(self)
    end

    validates :title, :description, :start_date, :end_date, presence: true
    validates :currency, inclusion: { in: Money::Currency.all.map(&:iso_code) }
    validate :end_date_after_start_date
    validate :start_date_within_set_lead_time
    validate :duration_within_set_max

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

      event :mark_rejected do
        transitions from: [:under_review, :onboarding], to: :rejected
      end

      event :mark_onboarded do
        transitions from: :onboarding, to: :onboarded, guard: :onboarding_complete?
      end

      event :mark_expired do
        transitions from: :onboarded, to: :expired
      end

      event :mark_terminated do
        transitions from: :onboarded, to: :terminated
      end
    end

    def status
      case aasm_state.to_sym
      when :onboarded
        :active
      when :under_review, :onboarding
        :onboarding
      when :expired, :terminated, :rejected
        :completed
      end
    end

    def status_text
      status.to_s.humanize
    end

    def status_color
      case status
      when :active then "success"
      when :onboarding then "info"
      else "muted"
      end
    end

    # Renders the contract window like "Jan–Jun 2026", collapsing to a single
    # month ("Apr 2026") or spanning years ("Dec 2025–Feb 2026") when needed.
    def period_label
      return if start_date.nil?

      return start_date.strftime("%b %Y") if end_date.nil? || (start_date.month == end_date.month && start_date.year == end_date.year)

      if start_date.year == end_date.year
        "#{start_date.strftime("%b")}–#{end_date.strftime("%b %Y")}"
      else
        "#{start_date.strftime("%b %Y")}–#{end_date.strftime("%b %Y")}"
      end
    end

    # The steps a contractor must complete before payments can be sent, each as
    # { label:, complete: }. Rendered in the contractor show modal.
    def onboarding_checklist
      legal_entity = payee.legal_entity

      [
        { key: :organizer_signature, label: "Contract signed by organizer", complete: contract_signed_by?(:organizer) },
        { key: :hcb_review, label: "Contract reviewed by HCB operations", complete: !under_review? && !rejected? },
        { key: :tax_form, label: "W-9 / W-8BEN submitted", complete: legal_entity&.latest_tax_form&.completed? || false },
        { key: :contractor_signature, label: "Contract signed by contractor", complete: contract_signed_by?(:contractor) },
        { key: :payout_method, label: "Payout method configured", complete: legal_entity&.default_payout_method.present? },
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
            "payee_name"  => payee.display_name,
            "title"       => title,
            "description" => description,
            "rate"        => rate.format,
            "start_date"  => start_date.to_fs(:long),
            "end_date"    => end_date.to_fs(:long),
            "documents"   => (file.attached? ? [{ "name" => file.blob.filename.to_s, "file" => Rails.application.routes.url_helpers.rails_blob_url(file) }] : nil)
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

    # The contractor isn't emailed when the contract is sent; they're notified
    # only once HCB signs
    def contract_notify_when_sent
      false
    end

    def contract_notify_hcb?
      false
    end

    def notify_mailer_for(party)
      return super unless party.contractor?

      Payroll::PositionMailer.with(position: self, party:).onboarding.deliver_later
    end

    private

    # Notifying/scheduling reminders for the contractor is best-effort: this
    # runs from inside the DocuSeal webhook's transaction (via
    # Contract::Party#mark_signed! → Contract#on_party_signed), so a job
    # enqueue failure here must not roll back the signature that already
    # happened on DocuSeal's side.
    def notify_contractor_of_onboarding(contractor)
      contractor.notify
      contractor.schedule_reminders
    rescue => e
      Rails.error.report(e, context: { payroll_position_id: id })
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

  end
end
