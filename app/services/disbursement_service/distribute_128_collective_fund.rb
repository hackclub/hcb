# frozen_string_literal: true

module DisbursementService
  # Hack Club has partnered with 128 Collective (https://128collective.org/) to
  # build a directory featuring climate-focused organizations that run on HCB.
  #
  # HCB Climate Directory: https://hackclub.com/fiscal-sponsorship/climate/
  #
  # The directory include an option to donate to HCB's Climate Fund.
  # This fund is distributed evenly to all 128 Collective's recommended
  # organizations on HCB on a monthly basis.
  class Distribute128CollectiveFund
    def run
      return if recommended_organizations.none?
      return if distributed_amount_cents <= 0

      ActiveRecord::Base.transaction do
        recommended_organizations.find_each(batch_size: 100) do |org|
          DisbursementService::Create.new(
            source_event_id: fund.id, destination_event_id: org.id,
            name: "128 Collective Climate Fund (#{month})",
            amount: distributed_amount,
            requested_by_id: nil
          ).run
        end
      end
    end

    def distributed_amount
      @distributed_amount ||= Money.new(distributed_amount_cents).dollars
    end

    def distributed_amount_cents
      (fund_balance_cents / recommended_organizations.count).floor
    end

    def recommended_organizations
      Event.includes(:event_tags).where(event_tags: { name: EventTag::Tags::PARTNER_128_COLLECTIVE_RECOMMENDED })
    end

    def fund
      Event.find(EventMappingEngine::EventIds::PARTNER_128_COLLECTIVE_FUND)
    end

    def fund_balance_cents
      fund.balance_available_v2_cents
    end

    def month
      # Ex. August 2023
      @month ||= Date.today.strftime("%B %Y")
    end

  end
end
