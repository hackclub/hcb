# frozen_string_literal: true

module HcbCodeService
  class CanDispute
    def initialize(hcb_code:)
      @hcb_code = hcb_code
    end

    # Returns an array: [can_dispute: boolean, error_reason: string || nil]
    # error_reason will be nil, unless it can not be disputed — which then it
    # would contain the reason why it can not be disputed.
    def run
      if @hcb_code.no_transactions?
        return [false, "This is not a valid transaction"]
      end

      if @hcb_code.stripe_card?
        # Stripe allows disputes on card transactions captured fewer than 110
        # days ago. We are decreasing this to 90 days for our users. This 20 day
        # buffer will give Operations a chance to work with the reporter (user)
        # to file the dispute with Stripe.
        if @hcb_code.date + 90.days >= Date.today
          [true, nil]
        else
          [false, "Card transactions older than 90 days can not be disputed."]
        end

      elsif @hcb_code.donation?
        # Disputes made on donations are for refunding the donation to the donor.
        # As far as I (@garyhtou) can tell, Stripe does not have a date limitation
        # for this (we can refund donations from 3 years ago).
        [true, nil]

      elsif @hcb_code.unknown?
        # Since these are direct to bank account transactions (such as Rippling
        # Payroll), we don't necessarily have a set way to disputing them. To
        # simplify ops, we'll limit these types of disputes to 90 days after
        # their posting to our underlying bank account.
        if @hcb_code.date + 90.days >= Date.today || @hcb_code.amount_cents >= 0
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
