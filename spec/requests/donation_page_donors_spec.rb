# frozen_string_literal: true

require "rails_helper"

# The donor cards belong to the first screen of the donation page. Every other
# render of `donations/start_donation` — tier screens, and the re-renders that
# follow a failed submission — leaves them out, so the ivars they read must be
# empty arrays rather than nil. See https://github.com/hackclub/hcb/issues/14544
RSpec.describe "Donation page donors", type: :request do
  let(:event) { create(:event, show_recent_donors: true, show_top_donors: true) }

  # Both cards hide themselves below a minimum, so seed comfortably past it.
  # Creating a donation mints a Stripe PaymentIntent; these are only ever read
  # back out of the database, so skip it.
  before do
    allow_any_instance_of(Donation).to receive(:create_stripe_payment_intent)

    10.times do |i|
      create(:donation, event:, name: "Donor #{i}", email: "donor#{i}@example.com",
                        amount: (i + 1) * 100, aasm_state: "deposited")
    end
  end

  it "shows both cards on the first screen" do
    get start_donation_donations_path(event.slug)

    expect(response).to have_http_status(:ok)
    expect(response.body).to include("Recent donors", "Top donors")
  end

  it "omits the cards when the org has them turned off" do
    event.update!(show_recent_donors: false, show_top_donors: false)

    get start_donation_donations_path(event.slug)

    expect(response).to have_http_status(:ok)
    expect(response.body).not_to include("Recent donors")
    expect(response.body).not_to include("Top donors")
  end

  # The regression: `make_donation` renders this template without ever running
  # the donor queries, which used to leave the ivars nil and blow up the view.
  it "re-renders without the cards after a failed submission" do
    post make_donation_donations_path(event.slug), params: {
      donation: { name: "Jane Smith", email: "", amount: "12.34" }
    }

    expect(response).to have_http_status(:unprocessable_content)
    expect(response.body).not_to include("Recent donors")
    expect(response.body).not_to include("Top donors")
  end
end
