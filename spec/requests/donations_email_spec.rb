# frozen_string_literal: true

require "rails_helper"

RSpec.describe "Donation email validation", type: :request do
  let(:event) { create(:event) }

  def make_donation(donation)
    post make_donation_donations_path(event.slug), params: { donation: { name: "Jane Smith", amount: "12.34" }.merge(donation) }
  end

  it "re-renders the form instead of erroring when the email is invalid" do
    expect(StripeService::Customer).not_to receive(:create)

    expect { make_donation(email: "jane@") }.not_to change(Donation, :count)

    expect(response).to have_http_status(:unprocessable_content)
    expect(response.body).to include("does not appear to be valid")
  end

  it "does not error on a bare POST that omits the email" do
    expect(StripeService::Customer).not_to receive(:create)

    expect { make_donation(email: nil) }.not_to change(Donation, :count)

    expect(response).to have_http_status(:unprocessable_content)
  end
end
