# frozen_string_literal: true

class Ledger
  class Item
    # The ledger item counterpart of HcbCodeService::CanDispute.
    class CanDispute
      def initialize(ledger_item:)
        @ledger_item = ledger_item
      end

      # Returns an array: [can_dispute: boolean, error_reason: string || nil]
      # error_reason will be nil, unless it can not be disputed — which then it
      # would contain the reason why it can not be disputed.
      def run
        if @ledger_item.ct_count.zero? && @ledger_item.cpt_count.zero?
          return [false, "This is not a valid transaction"]
        end

        case @ledger_item.linked_object_type
        when "CardCharge"
          # A force capture was never authorized, so there's nothing for Stripe
          # to dispute.
          return [false, "Can not dispute this type of transaction"] if @ledger_item.linked_object.remote_stripe_iauth_id.nil?

          # Stripe allows disputes on card transactions captured fewer than 110
          # days ago. We are decreasing this to 90 days for our users. This 20 day
          # buffer will give Operations a chance to work with the reporter (user)
          # to file the dispute with Stripe.
          if @ledger_item.datetime.to_date + 90.days >= Date.today
            [true, nil]
          else
            [false, "Card transactions older than 90 days can not be disputed."]
          end

        when "Donation"
          # Disputes made on donations are for refunding the donation to the donor.
          # As far as I (@garyhtou) can tell, Stripe does not have a date limitation
          # for this (we can refund donations from 3 years ago).
          [true, nil]

        when nil
          # Since these are direct to bank account transactions (such as Rippling
          # Payroll), we don't necessarily have a set way to disputing them. To
          # simplify ops, we'll limit these types of disputes to 90 days after
          # their posting to our underlying bank account.
          if @ledger_item.datetime.to_date + 90.days >= Date.today || @ledger_item.amount_cents >= 0
            [true, nil]
          else
            [false, "Bank account transactions older than 90 days can not be disputed."]
          end

        else
          [false, "Can not dispute this type of transaction"]
        end
      end

    end

  end

end
