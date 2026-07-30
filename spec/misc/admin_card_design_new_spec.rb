# frozen_string_literal: true

require "rails_helper"

RSpec.describe AdminController, type: :controller do
  include SessionSupport

  before { create_session(create(:user, :make_admin), verified: true) }

  describe "#stripe_card_personalization_design_new" do
    render_views

    it "renders the form" do
      get :stripe_card_personalization_design_new

      expect(response).to have_http_status(:ok)
      expect(response.body).to include(%(name="name"))
      expect(response.body).to include(%(name="color"))
      expect(response.body).to include(%(name="logo"))
    end
  end

  describe "#stripe_card_personalization_design_create" do
    # The file field is `required`, but the action used to `return` on a missing
    # logo, answering a bare 204 rather than telling the admin anything.
    it "sends the admin back with an error when the logo is missing" do
      post :stripe_card_personalization_design_create, params: { name: "Sapphire", color: "white" }

      expect(response).to redirect_to(stripe_card_personalization_design_new_admin_index_path)
      expect(flash[:error]).to eq("A PNG logo is required.")
    end

    it "surfaces a failure from Stripe instead of 500ing" do
      allow(StripeCardService::PersonalizationDesign::Create)
        .to receive(:new).and_raise(StandardError, "Stripe said no")

      post :stripe_card_personalization_design_create, params: {
        name: "Sapphire",
        color: "white",
        logo: fixture_file_upload(Rails.root.join("spec/fixtures/files/receipt.png"), "image/png"),
      }

      expect(response).to redirect_to(stripe_card_personalization_design_new_admin_index_path)
      expect(flash[:error]).to eq("Stripe said no")
    end
  end
end
