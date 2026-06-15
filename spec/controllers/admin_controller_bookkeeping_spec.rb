# frozen_string_literal: true

require "rails_helper"

RSpec.describe AdminController do
  include SessionSupport
  render_views

  describe "#bookkeeping" do
    it "renders the bookkeeping lookup with a React on Rails mount" do
      sign_in(create(:user, :make_admin))

      get(:bookkeeping)
      document = Nokogiri::HTML(response.body)

      expect(response).to have_http_status(:ok)
      expect(document.css('[data-component-name="BookkeepingStripeChargeLookup"]').size).to eq(1)
      expect(document.css('[data-react-class="BookkeepingStripeChargeLookup"]')).to be_empty
    end
  end
end
