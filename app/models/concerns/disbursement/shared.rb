# frozen_string_literal: true

class Disbursement
  module Shared
    extend ActiveSupport::Concern

    included do
      include PgSearch::Model
      pg_search_scope :search_name, against: [:name]

      # Scopes
      scope :not_card_grant_related, -> { left_joins(source_subledger: :card_grant, destination_subledger: :card_grant).where("card_grants.id IS NULL AND card_grants_subledgers.id IS NULL") }
      scope :fulfilled, -> { deposited }
      scope :reviewing_or_processing, -> { where(aasm_state: [:reviewing, :pending, :in_transit]) }

      # Associations
      belongs_to :destination_event, foreign_key: "event_id", class_name: "Event", inverse_of: "incoming_disbursements"
      belongs_to :source_event, class_name: "Event", inverse_of: "outgoing_disbursements"
      belongs_to :destination_subledger, class_name: "Subledger", optional: true
      belongs_to :source_subledger, class_name: "Subledger", optional: true

      belongs_to(:source_transaction_category, class_name: "TransactionCategory", optional: true)
      belongs_to(:destination_transaction_category, class_name: "TransactionCategory", optional: true)

      belongs_to :fulfilled_by, class_name: "User", optional: true
      belongs_to :requested_by, class_name: "User", optional: true

      has_one :card_grant, foreign_key: :disbursement_id, inverse_of: :disbursement, required: false

      # AASM
      include AASM
      aasm timestamps: true, whiny_persistence: true do
        state :reviewing, initial: true # Being reviewed by an admin
        state :pending                  # Waiting to be processed by the TX engine
        state :scheduled                # Has been scheduled and will be sent!
        state :in_transit               # Transfer started on remote bank
        state :deposited                # Transfer completed!
        state :rejected                 # Rejected by admin
        state :errored                  # oh no! an error!

        event :mark_approved do
          after do |fulfilled_by|
            update(fulfilled_by:)
            canonical_pending_transactions.update_all(fronted: true)
          end
          transitions from: [:reviewing, :scheduled], to: :pending
        end

        event :mark_in_transit do
          transitions from: [:pending, :scheduled], to: :in_transit
        end

        event :mark_deposited do
          transitions from: :in_transit, to: :deposited
        end

        event :mark_errored do
          after do
            canonical_pending_transactions.each { |cpt| cpt.decline! }
          end
          transitions from: [:pending, :in_transit], to: :errored
        end

        event :mark_rejected do
          after do |fulfilled_by|
            update(fulfilled_by:)
            canonical_pending_transactions.each { |cpt| cpt.decline! }
            create_activity(key: "disbursement.rejected", owner: fulfilled_by)
          end
          transitions from: [:scheduled, :reviewing, :pending], to: :rejected
        end

        event :mark_scheduled do
          after do |fulfilled_by|
            update(fulfilled_by:)
          end
          transitions from: [:pending, :reviewing, :in_review], to: :scheduled
        end

      end

      # Misc. methods
      alias_attribute :approved_at, :pending_at
      # Returns the perceived time of the transfer to an event with fronting enabled
      def transferred_at
        # `approved_at` isn't set on some old disbursements, so fall back to `in_transit_at`.
        approved_at || in_transit_at
      end

      def fee_waived?
        !should_charge_fee?
      end

      def inter_event_transfer?
        !source_subledger_id && !destination_subledger_id
      end

      def fulfilled?
        deposited?
      end

      def processed?
        in_transit? || deposited?
      end

      def outgoing_hcb_code
        "HCB-#{TransactionGroupingEngine::Calculate::HcbCode::OUTGOING_DISBURSEMENT_CODE}-#{id}"
      end

      def incoming_hcb_code
        "HCB-#{TransactionGroupingEngine::Calculate::HcbCode::INCOMING_DISBURSEMENT_CODE}-#{id}"
      end

      def canonical_transactions
        @canonical_transactions ||= CanonicalTransaction.where(hcb_code: [outgoing_hcb_code, incoming_hcb_code])
      end

      def canonical_pending_transactions
        @canonical_pending_transactions ||= ::CanonicalPendingTransaction.where(hcb_code: [outgoing_hcb_code, incoming_hcb_code])
      end

      # State methods
      def state
        if fulfilled?
          :success
        elsif processed? || pending?
          if destination_event.can_front_balance?
            :success
          else
            :muted
          end
        elsif rejected?
          :error
        elsif scheduled?
          :info
        elsif errored?
          :error
        elsif reviewing?
          :muted
        else
          :info
        end
      end
      alias_method :status, :state

      def state_text
        if fulfilled?
          "fulfilled"
        elsif processed? || pending?
          if destination_event.can_front_balance?
            "fulfilled"
          else
            "processing"
          end
        elsif rejected? && approved_at.present? # Disbursements that were approved, then rejected
          "canceled"
        elsif rejected?
          "rejected"
        elsif scheduled?
          "scheduled"
        elsif errored?
          "errored"
        elsif reviewing?
          "pending"
        else
          "pending"
        end
      end

      def state_icon
        "checkmark" if fulfilled? || processed? || (pending? && destination_event.can_front_balance?)
      end

      # Special appearance methods
      def special_appearance
        Disbursement::SPECIAL_APPEARANCES[special_appearance_name]
      end

      def special_appearance_name
        return nil if canonical_pending_transactions.with_custom_memo.any? || canonical_transactions.with_custom_memo.any?

        Disbursement::SPECIAL_APPEARANCES.each do |key, value|
          return key if value[:qualifier].call(self)
        end

        nil
      end

      def special_appearance?
        !special_appearance_name.nil?
      end

      def special_appearance_memo
        special_appearance&.[](:memo)
      end

    end
  end

end
