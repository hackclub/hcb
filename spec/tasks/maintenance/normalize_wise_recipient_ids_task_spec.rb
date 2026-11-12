# frozen_string_literal: true

require "rails_helper"

RSpec.describe Maintenance::NormalizeWiseRecipientIdsTask do
  it "reduces a stored recipient URL to its UUID" do
    payout_method = LegalEntity::PayoutMethod::WiseTransfer.new
    payout_method.wise_recipient_id = "https://wise.com/recipients/86b41d15-1024-47ee-9e05-1891a912e450?new=undefined"
    payout_method.clear_changes_information
    allow(payout_method).to receive(:update_columns)

    described_class.process(payout_method)

    expect(payout_method).to have_received(:update_columns).with(wise_recipient_id: "86b41d15-1024-47ee-9e05-1891a912e450")
  end
end
