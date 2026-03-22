# frozen_string_literal: true

require "rails_helper"

RSpec.describe PayoutService::Donation::Create do
  include DonationSupport

  before do
    allow_any_instance_of(DonationPayout).to receive(:create_stripe_payout).and_return(true)
    stub_donation_payment_intent_creation
  end

  def setup_context
    donation = create(:donation, aasm_state: :in_transit)

    service = described_class.new(donation_id: donation.id)
    allow(service).to receive(:funds_available?).and_return(true)

    { donation:, service: }
  end

  it "creates a payout" do
    setup_context => { service: }

    expect do
      service.run
    end.to change(DonationPayout, :count).by(1)
  end

  it "creates a fee_reimbursement" do
    setup_context => { service: }

    expect do
      service.run
    end.to change(FeeReimbursement, :count).by(1)
  end

  it "updates donation with relationships" do
    setup_context => { donation:, service: }
    expect(donation.payout_id).to be_nil
    expect(donation.fee_reimbursement_id).to be_nil

    service.run

    donation.reload

    expect(donation.payout_id).to be_present
    expect(donation.fee_reimbursement_id).to be_present
  end
end
