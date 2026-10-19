# frozen_string_literal: true

require "rails_helper"

RSpec.describe Column::AccountNumberController do
  include SessionSupport

  describe "#create" do
    it "refuses to create an account number for a Playground Mode organization" do
      user = create(:user)
      event = create(:event, :demo_mode)
      create(:organizer_position, user:, event:, role: :manager)
      create_session(user, verified: true)

      expect(ColumnService).not_to receive(:post)

      post(:create, params: { event_id: event.slug })

      expect(response).to have_http_status(:redirect)
      expect(flash[:error]).to eq("You are not authorized to perform this action.")
      expect(event.reload.column_account_number).to be_nil
    end
  end
end
