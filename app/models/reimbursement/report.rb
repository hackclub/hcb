# frozen_string_literal: true

# == Schema Information
#
# Table name: reimbursement_reports
#
#  id                         :bigint           not null, primary key
#  aasm_state                 :string
#  deleted_at                 :datetime
#  expense_number             :integer          default(0), not null
#  invite_message             :text
#  maximum_amount_cents       :integer
#  name                       :text
#  reimbursed_at              :datetime
#  reimbursement_approved_at  :datetime
#  reimbursement_requested_at :datetime
#  rejected_at                :datetime
#  submitted_at               :datetime
#  created_at                 :datetime         not null
#  updated_at                 :datetime         not null
#  event_id                   :bigint           not null
#  invited_by_id              :bigint
#  reviewer_id                :bigint
#  user_id                    :bigint           not null
#
# Indexes
#
#  index_reimbursement_reports_on_event_id       (event_id)
#  index_reimbursement_reports_on_invited_by_id  (invited_by_id)
#  index_reimbursement_reports_on_reviewer_id    (reviewer_id)
#  index_reimbursement_reports_on_user_id        (user_id)
#
# Foreign Keys
#
#  fk_rails_...  (event_id => events.id)
#  fk_rails_...  (invited_by_id => users.id)
#  fk_rails_...  (user_id => users.id)
#
module Reimbursement
  class Report < ApplicationRecord
    include ::Shared::AmpleBalance
    belongs_to :user
    belongs_to :event
    belongs_to :inviter, class_name: "User", foreign_key: "invited_by_id", optional: true, inverse_of: :created_reimbursement_reports
    belongs_to :reviewer, class_name: "User", optional: true, inverse_of: :assigned_reimbursement_reports

    has_paper_trail ignore: :expense_number

    monetize :maximum_amount_cents, allow_nil: true
    monetize :amount_to_reimburse_cents, allow_nil: true
    monetize :amount_cents, as: "amount", allow_nil: true
    validates :maximum_amount_cents, numericality: { greater_than: 0 }, allow_nil: true
    has_many :expenses, foreign_key: "reimbursement_report_id", inverse_of: :report, dependent: :delete_all
    has_one :payout_holding, inverse_of: :report
    alias_attribute :report_name, :name
    attribute :name, :string, default: -> { "Expenses from #{Time.now.strftime("%B %e, %Y")}" }

    scope :search, ->(q) { joins(:user).where("users.full_name ILIKE :query OR reimbursement_reports.name ILIKE :query", query: "%#{User.sanitize_sql_like(q)}%") }
    scope :pending, -> { where(aasm_state: ["draft", "submitted", "reimbursement_requested"]) }
    scope :to_calculate_total, -> { where.not(aasm_state: ["rejected"]) }

    include AASM
    include Commentable
    include Hashid::Rails

    include PublicActivity::Model
    tracked owner: proc{ |controller, record| controller&.current_user }, recipient: proc { |controller, record| record.user }, event_id: proc { |controller, record| record.event.id }, only: [:create]

    broadcasts_refreshes_to ->(report) { report }

    acts_as_paranoid

    after_create_commit do
      ReimbursementMailer.with(report: self).invitation.deliver_later if inviter != user
    end

    aasm timestamps: true do
      state :draft, initial: true
      state :submitted
      state :reimbursement_requested
      state :reimbursement_approved
      state :reimbursed
      state :rejected
      state :reversed

      event :mark_submitted do
        transitions from: [:draft, :reimbursement_requested], to: :submitted do
          guard do
            user.payout_method.present? && !exceeds_maximum_amount? && expenses.any? && !missing_receipts?
          end
        end
        after do
          if team_review_required?
            ReimbursementMailer.with(report: self).review_requested.deliver_later
            create_activity(key: "reimbursement_report.review_requested", owner: user, recipient: reviewer.presence || event, event_id: event.id)
          else
            expenses.pending.each do |expense|
              expense.mark_approved!
            end
            self.mark_reimbursement_requested!
          end
        end
      end

      event :mark_reimbursement_requested do
        transitions from: :submitted, to: :reimbursement_requested do
          guard do
            expenses.approved.count > 0 && amount_to_reimburse > 0 && (!maximum_amount_cents || expenses.approved.sum(:amount_cents) <= maximum_amount_cents) && Shared::AmpleBalance.ample_balance?(amount_to_reimburse_cents, event)
          end
        end
        after do
          # ReimbursementJob::Nightly.perform_later
        end
      end

      event :mark_reimbursement_approved do
        transitions from: :reimbursement_requested, to: :reimbursement_approved do
          guard do
            expenses.approved.count > 0 && amount_to_reimburse > 0 && (!maximum_amount_cents || expenses.approved.sum(:amount_cents) <= maximum_amount_cents) && Shared::AmpleBalance.ample_balance?(expenses.approved.sum(:amount_cents), event)
          end
        end
        after do
          # ReimbursementJob::Nightly.perform_later
          ReimbursementMailer.with(report: self).reimbursement_approved.deliver_later
          create_activity(key: "reimbursement_report.approved", owner: user)
        end
      end

      event :mark_rejected do
        transitions from: [:draft, :submitted, :reimbursement_requested], to: :rejected
        after do
          ReimbursementMailer.with(report: self).rejected.deliver_later
        end
      end

      event :mark_draft do
        transitions from: [:submitted, :reimbursement_requested, :rejected], to: :draft
      end

      event :mark_reimbursed do
        transitions from: :reimbursement_approved, to: :reimbursed
      end

      event :mark_reversed do
        transitions from: :reimbursed, to: :reversed
      end
    end

    def status_text
      return "Review Requested" if submitted?
      return "Processing" if reimbursement_requested?
      return "⚠️ Processing" if reimbursed? && payout_holding&.failed?
      return "In Transit" if reimbursement_approved?
      return "In Transit" if reimbursed? && !payout_holding.sent?
      return "Cancelled" if reversed?

      aasm_state.humanize.titleize
    end

    def admin_status_text
      return "HCB Review Requested" if reimbursement_requested?
      return "Organizers Reviewing" if submitted?

      status_text
    end

    def status_color
      return "muted" if draft?
      return "info" if submitted?
      return "error" if rejected?
      return "purple" if reimbursement_requested?
      return "warning" if reimbursed? && payout_holding&.failed? || reversed?
      return "success" if reimbursement_approved? || reimbursed?

      return "primary"
    end

    def status_description
      return "Review requested from #{event.name}" if submitted?
      return "HCB is reviewing this report" if reimbursement_requested?

      nil
    end

    def locked?
      !draft?
    end

    def unlockable?
      submitted? || reimbursement_requested?
    end

    def closed?
      reimbursement_approved? || reimbursed? || rejected?
    end

    def amount_cents
      return amount_to_reimburse_cents if reimbursement_requested? || reimbursement_approved? || reimbursed?

      expenses.sum(:amount_cents)
    end

    def amount_to_reimburse_cents
      return [expenses.approved.sum(:amount_cents), maximum_amount_cents].min if maximum_amount_cents

      expenses.approved.sum(:amount_cents)
    end

    def last_reimbursement_requested_by
      last_user_change_to(aasm_state: "reimbursement_requested")
    end

    def last_reimbursement_approved_by
      last_user_change_to(aasm_state: "reimbursement_approved")
    end

    def last_rejected_by
      last_user_change_to(aasm_state: "rejected")
    end

    def comment_recipients_for(comment)
      users = []
      users += self.comments.map(&:user)
      users += self.comments.flat_map(&:mentioned_users)
      users << self.user

      if comment.admin_only?
        users << self.event.point_of_contact
        return users.uniq.select(&:admin?).reject(&:no_threads?).excluding(comment.user).collect(&:email_address_with_name)
      end

      users.uniq.excluding(comment.user).reject(&:no_threads?).collect(&:email_address_with_name)
    end

    def comment_mentionable(current_user: nil)
      users = []
      users += self.comments.includes(:user).map(&:user)
      users += self.comments.flat_map(&:mentioned_users)
      users += self.event.users
      users << self.user

      users.uniq
    end

    def comment_mailer_subject
      return "New comment on #{self.name}."
    end

    def initial_draft?
      draft? && submitted_at.nil?
    end

    def team_review_required?
      !event.users.include?(user) || OrganizerPosition.find_by(user:, event:)&.member? || (event.reimbursements_require_organizer_peer_review && event.users.size > 1)
    end

    def reimbursement_confirmation_message
      return nil if expenses.pending.none?

      "#{expenses.pending.count} #{"expense".pluralize(expenses.pending.count)} #{expenses.pending.count == 1 ? "hasn't" : "haven't"} been approved; if you continue, #{expenses.pending.count == 1 ? "it" : "these"} will not be reimbursed."
    end

    def missing_receipts?
      expenses.complete.with_receipt.count != expenses.count
    end

    def exceeds_maximum_amount?
      maximum_amount_cents && amount_cents > maximum_amount_cents
    end

    private

    def last_user_change_to(...)
      user_id = versions.where_object_changes_to(...).last&.whodunnit

      user_id && User.find(user_id)
    end

  end
end
