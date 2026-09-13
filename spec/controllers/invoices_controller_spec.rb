# frozen_string_literal: true

require "rails_helper"

describe InvoicesController do
  include SessionSupport

  render_views

  # The invoice form partial is shared between the full page and the modal on
  # the index, so render both.
  describe "the invoice form" do
    let(:user) { create(:user) }
    let(:event) { create(:event, organizers: [user]) }

    before { create_session(user, verified: true) }

    it "renders on the new page" do
      get :new, params: { event_id: event.friendly_id }

      expect(response).to have_http_status(:ok)
    end

    it "renders in the index modal" do
      get :index, params: { event_id: event.friendly_id }

      expect(response).to have_http_status(:ok)
    end
  end

  describe "create" do
    let(:user) { create(:user) }
    let(:event) { create(:event, organizers: [user]) }

    let(:valid_params) do
      {
        event_id: event.friendly_id,
        invoice: {
          due_date: 30.days.from_now.to_date.to_s,
          item_description: "Silver Sponsorship",
          item_amount: "500.00",
          sponsor_attributes: {
            name: "Raviga Capital",
            contact_email: "peter.gregory@ravigacapital.com",
            address_line1: "1 Letterman Drive",
            address_city: "San Francisco",
            address_state: "CA",
            address_postal_code: "94129",
            address_country: "US"
          }
        }
      }
    end

    before { create_session(user, verified: true) }

    # `type="email"` lets `peter.gregory@ravigacapital` through, but Sponsor's
    # server-side validation requires a TLD.
    context "when the sponsor's email is invalid" do
      let(:params) do
        valid_params.deep_merge(
          invoice: { sponsor_attributes: { contact_email: "peter.gregory@ravigacapital" } }
        )
      end

      it "re-renders the form with the error instead of reporting it" do
        expect(Rails.error).not_to receive(:report)
        expect(StripeService::Customer).not_to receive(:create)

        expect { post :create, params: params }.not_to change(Sponsor, :count)

        expect(response).to have_http_status(:unprocessable_content)
        expect(response.body).to include("Contact email does not appear to be a valid email address")
      end

      it "keeps what was already filled in" do
        post :create, params: params

        expect(response.body).to include('value="peter.gregory@ravigacapital"')
        expect(response.body).to include('value="Raviga Capital"')
        expect(response.body).to include('value="San Francisco"')
        expect(response.body).to include('value="Silver Sponsorship"')
        expect(response.body).to include('value="500.0"')
      end
    end

    context "when the due date is blank" do
      it "re-renders the form rather than raising out of Date.parse" do
        expect(Rails.error).not_to receive(:report)
        allow_any_instance_of(Sponsor).to receive(:create_stripe_customer).and_return(true)

        post :create, params: valid_params.deep_merge(invoice: { due_date: "" })

        expect(response).to have_http_status(:unprocessable_content)
        expect(response.body).to include("Due date can&#39;t be blank")
      end
    end

    context "when the amount is below the $1 minimum" do
      it "re-renders the form with the error and the sponsor's details" do
        expect(Rails.error).not_to receive(:report)
        allow_any_instance_of(Sponsor).to receive(:create_stripe_customer).and_return(true)

        post :create, params: valid_params.deep_merge(invoice: { item_amount: "0.50" })

        expect(response).to have_http_status(:unprocessable_content)
        expect(response.body).to include("Item amount must be at least $1")
        expect(response.body).to include('value="Raviga Capital"')
      end
    end
  end

end
