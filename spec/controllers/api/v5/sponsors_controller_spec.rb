# frozen_string_literal: true

require "rails_helper"

RSpec.describe Api::V5::SponsorsController do
  render_views

  # Creating a sponsor registers a Stripe customer; this spec is about who may
  # read one.
  before do
    allow(StripeService::Customer).to receive(:create).and_return(
      Stripe::Customer.construct_from(id: "cus_#{SecureRandom.alphanumeric(10)}")
    )
  end

  let!(:transparent) { create(:event, :with_positive_balance, is_public: true) }
  let!(:sponsor) { create(:sponsor, event: transparent, name: "Acme Corp", contact_email: "ap@acme.test") }

  def authenticate_as(user)
    request.headers["Authorization"] = "Bearer #{create(:api_token, user:).token}"
  end

  # Sponsors have no v3 entity: a transparent organization does not publish who
  # invoices it, so transparency must not reach them.
  it "does not list a transparent organization's sponsors anonymously" do
    get :index, params: {}, as: :json

    expect(response).to have_http_status(:ok)
    expect(response.parsed_body["data"]).to be_empty
  end

  it "refuses a sponsor to an anonymous caller even on a transparent organization" do
    get :show, params: { id: sponsor.public_id }, as: :json

    expect(response).to have_http_status(:forbidden)
  end

  it "lists sponsors to an organizer" do
    user = create(:user)
    create(:organizer_position, user:, event: transparent, role: :reader)
    authenticate_as(user)

    get :index, params: {}, as: :json

    expect(response.parsed_body["data"].map { |s| s["name"] }).to contain_exactly("Acme Corp")
    expect(response.parsed_body["data"].first).to include("contact_email" => "ap@acme.test")
  end

  it "withholds the stripe customer id from a non-auditor organizer" do
    user = create(:user)
    create(:organizer_position, user:, event: transparent, role: :manager)
    authenticate_as(user)

    get :show, params: { id: sponsor.public_id }, as: :json

    expect(response).to have_http_status(:ok)
    expect(response.parsed_body).not_to include("stripe_customer_id")
  end

end
