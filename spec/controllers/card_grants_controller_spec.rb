# frozen_string_literal: true

require "rails_helper"

RSpec.describe CardGrantsController do
  include SessionSupport
  render_views

  describe "#new" do
    it "renders successfully" do
      user = create(:user)
      event = create(:event)
      create(:organizer_position, user:, event:)
      sign_in(user)

      expect(event.card_grant_setting).to be_nil

      get(:new, params: { event_id: event.friendly_id })

      expect(response).to have_http_status(:ok)
      expect(event.reload.card_grant_setting).to be_present
    end
  end
end
