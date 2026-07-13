# frozen_string_literal: true

module UserService
  # Maintains receipt_settled_at / receipt_due_at on a cardholder's outstanding
  # charges. Idempotent; safe to run every few minutes. The slide advances as new
  # charges settle; the shortening floor (inside CardLocking::Deadline) protects
  # the pile when trust is lost.
  class RefreshReceiptDeadlines
    def initialize(user:, now: Time.current)
      @user = user
      @now = now
    end

    def run
      return unless @user.stripe_cardholder

      trusted = @user.receipt_trusted?(now: @now)
      last_settled = @user.last_settled_charge_at
      enforcement_start_date = CardLocking.enforcement_start_date(@user)

      outstanding_charges.find_each do |hcb_code|
        hcb_code.materialize_card_locking!(now: @now, trusted:, last_settled_charge_at: last_settled, enforcement_start_date:)
      end
    end

    private

    def outstanding_charges
      HcbCode.card_locking_candidates
             .where(stripe_cardholders: { user_id: @user.id })
             .includes(:canonical_transactions, :receipts)
    end

  end
end
