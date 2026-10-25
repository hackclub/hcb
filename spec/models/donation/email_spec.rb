# frozen_string_literal: true

require "rails_helper"

# Stripe rejects some RFC-valid emails, which used to surface as a 500 instead
# of a form error. Anything that reaches Stripe must already pass our check.
RSpec.describe Donation, type: :model do
  let(:event) { create(:event) }

  def invalid_email_error(email)
    expect(StripeService::Customer).not_to receive(:create)

    donation = build(:donation, event:, email:)
    expect(donation).not_to be_valid
    donation.errors[:email]
  end

  it "rejects emails Stripe refuses even though they are RFC-valid" do
    ['"jane smith"@example.com', "jane(comment)@example.com", "jane@exämple.com", "jane@localhost"].each do |email|
      expect(invalid_email_error(email)).to be_present, "expected #{email} to be rejected"
    end
  end

  it "rejects an email that smuggles a second address past the form" do
    expect(invalid_email_error("jane@example.com\nmallory@example.com")).to be_present
  end

  it "validates an in-person donation's email when one is given" do
    expect(StripeService::Customer).not_to receive(:create)

    expect(build(:donation, event:, in_person: true, email: "not an email")).not_to be_valid
    expect(build(:donation, event:, in_person: true, email: nil)).to be_valid
  end

  # Our rules are a superset of what we know, not of what Stripe knows.
  it "turns a Stripe email rejection into a validation error instead of raising" do
    expect(StripeService::Customer).to receive(:create).and_raise(Stripe::InvalidRequestError.new("Invalid email address: jane@example.com", "email"))
    expect(StripeService::PaymentIntent).not_to receive(:create)

    donation = build(:donation, event:, email: "jane@example.com")

    expect(donation.save).to be(false)
    expect(donation.errors[:email]).to be_present
    expect(donation).to be_new_record
  end

  it "re-raises Stripe errors unrelated to the email" do
    expect(StripeService::Customer).to receive(:create).and_raise(Stripe::InvalidRequestError.new("No such customer", "customer"))

    expect { build(:donation, event:).save }.to raise_error(Stripe::InvalidRequestError)
  end
end
