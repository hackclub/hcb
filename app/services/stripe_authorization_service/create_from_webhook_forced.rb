# frozen_string_literal: true

module StripeAuthorizationService
  class CreateFromWebhookForced
    def initialize(stripe_transaction_id:)
      @stripe_transaction_id = stripe_transaction_id
    end

    def run
      cpt = nil

      # 1. fetch remote stripe transaction
      remote_stripe_transaction = ::Stripe::Issuing::Transaction.retrieve(
        @stripe_transaction_id
      )

      ActiveRecord::Base.transaction do
        # 2. idempotent import into the db
        rpst = ::PendingTransactionEngine::RawPendingStripeTransactionService::Stripe::ImportSingle.new(remote_stripe_transaction:).run

        # 3. idempotent canonize the newly added raw pending stripe transaction
        cpt = ::PendingTransactionEngine::CanonicalPendingTransactionService::ImportSingle::Stripe.new(raw_pending_stripe_transaction: rpst).run

        # 4. idempotent map to event
        ::PendingEventMappingEngine::Map::Single::Stripe.new(canonical_pending_transaction: cpt).run
      end

      if cpt
        user = cpt&.stripe_card&.user

        CanonicalPendingTransactionMailer.with(canonical_pending_transaction_id: cpt.id).notify_approved.deliver_later
        if user.sms_charge_notifications_enabled?
          CanonicalPendingTransaction::SendTwilioReceiptMessageJob.perform_later(cpt_id: cpt.id, user_id: user.id)
        end

        SuggestTagsJob.perform_later(event_id: cpt.event.id, hcb_code_id: cpt.local_hcb_code.id)

        if cpt.local_hcb_code&.stripe_cash_withdrawal?
          AdminMailer.with(hcb_code: cpt.local_hcb_code).cash_withdrawal_notification.deliver_later
        end

        spending_control = cpt.stripe_card.active_spending_control
        if spending_control.present?
          SpendingControlService.check_low_balance(spending_control, cpt.local_hcb_code)
        end

        if cpt&.stripe_card&.card_grant&.one_time_use
          PaperTrail.request(whodunnit: User.system_user.id) do
            cpt.stripe_card.freeze!(frozen_by: User.system_user)
          end
        end
      end
      TopupStripeJob.perform_later
    end

  end
end
