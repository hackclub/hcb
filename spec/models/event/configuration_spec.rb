# frozen_string_literal: true

require "rails_helper"

RSpec.describe Event::Configuration, type: :model do
  describe "validations" do
    let(:event) { create(:event) }
    let(:config) { event.config }

    describe "post_donation_redirect_url" do
      it "accepts valid URLs" do
        config.post_donation_redirect_url = "https://example.com/thank-you"
        expect(config).to be_valid

        config.post_donation_redirect_url = "http://example.com"
        expect(config).to be_valid
      end

      it "accepts nil or blank values" do
        config.post_donation_redirect_url = nil
        expect(config).to be_valid

        config.post_donation_redirect_url = ""
        expect(config).to be_valid
      end

      it "rejects invalid URLs" do
        config.post_donation_redirect_url = "not-a-url"
        expect(config).not_to be_valid

        config.post_donation_redirect_url = "ftp://example.com"
        expect(config).not_to be_valid
      end
    end

    describe "post_donation_include_details" do
      it "defaults to false" do
        new_event = create(:event)
        expect(new_event.config.post_donation_include_details).to eq(false)
      end

      it "can be set to true" do
        config.post_donation_include_details = true
        expect(config).to be_valid
        config.save!
        expect(config.reload.post_donation_include_details).to eq(true)
      end
    end
  end
end
