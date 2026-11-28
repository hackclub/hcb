# frozen_string_literal: true

require "rails_helper"

RSpec.describe Column::AccountNumberController do
  include SessionSupport

  describe "#create" do
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
        expect(frame.at_css("a[href='#{reveal_account_number_event_path(event, show_details: "false")}']")["aria-label"]).to eq("Hide account number")
      end

      context "when the eye asked for it from the page or the modal" do
        it "streams the new number into the page's frame and the whole modal, animating where it was clicked", :aggregate_failures do
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

          post(:create, params: { event_id: event.slug }, format: :turbo_stream)

          expect(response).to have_http_status(:ok)
          expect(response.media_type).to eq(Mime[:turbo_stream])
          streams = Nokogiri::HTML5.fragment(response.body).css("turbo-stream[action='replace']")
          expect(streams.map { |stream| stream["target"] }).to eq(%w[account_number_details account_number_modal])
          details, modal = streams.map { |stream| Nokogiri::HTML5.fragment(stream.at_css("template").inner_html) }

          expect(details.at_css("turbo-frame#account_number_details")).to be_present
          expect(details.css("[data-controller='reveal-animation']").map(&:text)).to eq(%w[987654321012 121145349])
          expect(details.at_css("form[action='#{event_column_account_number_path(event)}']")).to be_nil
          expect(details.at_css("a[href='#{reveal_account_number_event_path(event, show_details: "false")}']")).to be_present

          # The modal wasn't the one clicked (it's usually closed), so it gets the
          # numbers without the animation.
          expect(modal.at_css("turbo-frame#account_number_modal")).to be_present
          expect(modal.css("[data-controller='reveal-animation']")).to be_empty
          expect(modal.css("[data-controller='clipboard']").map { |copy| copy["data-clipboard-text-value"] }).to include("987654321012", "121145349")
          expect(modal.text).to include("CLNOUS66").and include("Receive-only")
          expect(modal.at_css("form[action='#{event_column_account_number_path(event)}'] button[aria-label='Show account number']")).to be_nil
          expect(modal.at_css("a[href='#{reveal_account_number_event_path(event, show_details: "false")}']")).to be_present
        end
      end
    end
  end
end
