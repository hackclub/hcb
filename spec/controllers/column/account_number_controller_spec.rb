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
        expect(frame.at_css("a[href='#{reveal_account_number_event_path(event, show_details: "false", tooltip_direction: :n)}']")["aria-label"]).to eq("Hide account number")
      end

      context "when the eye on the account number page asked for it" do
        it "renders the new number and routing number into the page's frame", :aggregate_failures do
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
          request.headers["Turbo-Frame"] = "account_number_details"

          post(:create, params: { event_id: event.slug })

          expect(response).to have_http_status(:ok)
          expect(response.body).not_to include("<html")
          frame = Nokogiri::HTML5.fragment(response.body).at_css("turbo-frame#account_number_details")
          expect(frame.css("[data-controller='reveal-animation']").map(&:text)).to eq(%w[987654321012 121145349])
          expect(frame.at_css("form[action='#{event_column_account_number_path(event)}']")).to be_nil
          expect(frame.at_css("a[href='#{reveal_account_number_event_path(event, show_details: "false", tooltip_direction: :n)}']")).to be_present
        end
      end

      context "when the eye in the account numbers modal asked for it" do
        it "renders the whole modal with the new number, badge and bank details", :aggregate_failures do
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
          request.headers["Turbo-Frame"] = "account_number_modal"

          post(:create, params: { event_id: event.slug })

          expect(response).to have_http_status(:ok)
          expect(response.body).not_to include("<html")
          frame = Nokogiri::HTML5.fragment(response.body).at_css("turbo-frame#account_number_modal")
          expect(frame.css("[data-controller='reveal-animation']").map(&:text)).to eq(%w[987654321012 121145349])
          expect(frame.text).to include("CLNOUS66").and include("Receive-only")
          expect(frame.at_css("form[action='#{event_column_account_number_path(event)}'] button[aria-label='Show account number']")).to be_nil
          expect(frame.at_css("a[href='#{reveal_account_number_event_path(event, show_details: "false", tooltip_direction: :s)}']")).to be_present
        end
      end
    end
  end
end
