# frozen_string_literal: true

require "rails_helper"

RSpec.describe Invoice, type: :model do
  before do
    expect_any_instance_of(Sponsor).to receive(:create_stripe_customer).and_return(true)
  end

  it "is valid" do
    invoice = create(:invoice)
    expect(invoice).to be_valid
  end
end
