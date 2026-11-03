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

    context "when rendering views" do
      render_views

      it "reveals a newly generated account number straight away", :aggregate_failures do
        user = create(:user)
        event = create(:event)
        create(:organizer_position, user:, event:, role: :manager)
        create_session(user, verified: true)

        allow(ColumnService).to receive(:post).and_return(
          "id"             => "acno_test",
          "account_number" => "987654321012",
          "routing_number" => "121145349",
          "bic"            => "CLNOUS66"
        )

        post(:create, params: { event_id: event.slug })

        frame = Nokogiri::HTML5(response.body).at_css("turbo-frame#account_number_reveal")
        expect(frame.at_css("[data-controller='reveal-animation']").text).to eq("987654321012")
        expect(frame.at_css("a[href^='#{reveal_account_number_event_path(event)}']")).to be_nil
      end
    end
  end
end
