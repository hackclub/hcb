# frozen_string_literal: true

require "rails_helper"

RSpec.describe "Event promotions", type: :request do
  let(:event) { create(:event, country: "US") }
  let(:user) { create(:user) }

  def sign_in_with(session)
    allow_any_instance_of(SessionsHelper)
      .to receive(:find_current_session)
      .and_return(session)
  end

  before do
    sign_in_with(create(:user_session, user:, expiration_at: 1.hour.from_now))
  end

  describe "HCB stickers perk" do
    context "as a member of a US organization" do
      before { create(:organizer_position, user:, event:, role: :member) }

      it "lets members request stickers with the organization slug prefilled" do
        get event_promotions_path(event)

        expect(response).to have_http_status(:ok)
        stickers = Nokogiri::HTML(response.body).at_css("#stickers")
        button = stickers.at_css("a.btn")
        expect(button.text).to eq("Request")
        expect(button["class"]).not_to include("disabled")
        expect(button["href"]).to include("prefill_Organization=#{event.slug}")
        expect(button["href"]).not_to include(ERB::Util.url_encode(event.name))
        expect(stickers.text).to include("only be shipped to 🇺🇸 US addresses")
      end
    end

    context "as a member of a non-US organization" do
      let(:event) { create(:event, country: "CA") }

      before { create(:organizer_position, user:, event:, role: :member) }

      it "marks the perk as ineligible with a tooltip" do
        get event_promotions_path(event)

        stickers = Nokogiri::HTML(response.body).at_css("#stickers")
        expect(stickers["class"]).to include("muted")
        expect(stickers.at_css("a.btn")).to be_nil
        tooltip = stickers.at_css(".tooltipped")
        expect(tooltip["aria-label"]).to include("US addresses")
        expect(tooltip.text).to include("Ineligible")
      end
    end

    context "as a reader" do
      before { create(:organizer_position, user:, event:, role: :reader) }

      it "disables the request button" do
        get event_promotions_path(event)

        button = Nokogiri::HTML(response.body).at_css("#stickers a.btn")
        expect(button["class"]).to include("disabled")
        expect(button["href"]).to eq(root_path)
      end
    end
  end
end
