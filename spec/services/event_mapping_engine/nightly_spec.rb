# frozen_string_literal: true

require "rails_helper"

RSpec.describe EventMappingEngine::Nightly do
  let(:service) { EventMappingEngine::Nightly.new }

  it "runs every mapper" do
    %i[
      map_column_account_number_transactions!
      map_stripe_transactions!
      map_check_deposits!
      map_stripe_top_ups!
      map_interest_payments!
      map_svb_sweep_transactions!
      map_hcb_codes_short!
    ].each do |mapper|
      expect(service).to receive(mapper).and_return(true)
    end

    expect(service.run).to be(true)
  end
end
