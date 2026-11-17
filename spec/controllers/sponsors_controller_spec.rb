# frozen_string_literal: true

require "rails_helper"

RSpec.describe SponsorsController, type: :controller do
  include SessionSupport

  describe "GET #index" do
    let(:event) { create(:event) }

    before do
      allow_any_instance_of(Sponsor).to receive(:create_stripe_customer)
      create(:sponsor, event:)
    end

    it "lists sponsors for an auditor" do
      create_session(create(:user, :make_auditor), verified: true)

      get :index

      expect(response).to have_http_status(:ok)
    end

    it "turns away an organization manager" do
      user = create(:user)
      create(:organizer_position, user:, event:, role: :manager)
      create_session(user, verified: true)

      get :index

      expect(response).to redirect_to(root_path)
      expect(flash[:error]).to eq("You are not authorized to perform this action.")
    end
  end
end
