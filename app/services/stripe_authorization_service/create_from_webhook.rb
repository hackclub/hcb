# frozen_string_literal: true

module StripeAuthorizationService
  class CreateFromWebhook
    def initialize(stripe_transaction_id:)
      @stripe_transaction_id = stripe_transaction_id
    end

    def run
      cpt = nil

      # 1. fetch remote stripe transaction (authorization)
      remote_stripe_transaction = StripeService::Issuing::Authorization.retrieve(@stripe_transaction_id)
      return unless remote_stripe_transaction

      ActiveRecord::Base.transaction do
        # 2. idempotent import into the db
        rpst = ::PendingTransactionEngine::RawPendingStripeTransactionService::Stripe::ImportSingle.new(remote_stripe_transaction:).run

        # 3. idempotent canonize the newly added raw pending stripe transaction
        cpt = ::PendingTransactionEngine::CanonicalPendingTransactionService::ImportSingle::Stripe.new(raw_pending_stripe_transaction: rpst).run

        # 4. idempotent map to event
        ::PendingEventMappingEngine::Map::Single::Stripe.new(canonical_pending_transaction: cpt).run

        # 5. instantly mark the transaction as declined if it was declined on Stripe's end
        unless remote_stripe_transaction.approved
          cpt.decline!
        end
      end

      if cpt
        user = cpt&.stripe_card&.user

        if remote_stripe_transaction.approved
          CanonicalPendingTransactionMailer.with(canonical_pending_transaction_id: cpt.id).notify_approved.deliver_later
          if user.sms_charge_notifications_enabled?
            CanonicalPendingTransactionJob::SendTwilioReceiptMessage.perform_later(cpt_id: cpt.id, user_id: user.id)
          end

          SuggestTagsJob.perform_later(event_id: cpt.event.id, hcb_code_id: cpt.local_hcb_code.id)

          if cpt.local_hcb_code&.stripe_cash_withdrawal?
            AdminMailer.with(hcb_code: cpt.local_hcb_code).cash_withdrawal_notification.deliver_later
          end
        else
          unless cpt&.stripe_card&.frozen?
            CanonicalPendingTransactionMailer.with(canonical_pending_transaction_id: cpt.id).notify_declined.deliver_later
            CanonicalPendingTransactionJob::SendTwilioDeclinedMessage.perform_later(cpt_id: cpt.id, user_id: user.id)
          end
        end
      end
    end

  end
end
