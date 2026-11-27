# frozen_string_literal: true

require "rails_helper"

RSpec.describe DisputesHelper, type: :helper do
  let(:user) { build(:user, full_name: "Ada Lovelace", email: "ada@example.com") }

  describe "#disputed_transactions_airtable_form_url" do
    it "prefills an HCB code's hashid as the transaction code" do
      hcb_code = create(:hcb_code)

      url = helper.disputed_transactions_airtable_form_url(hcb_code:, user:)

      expect(url).to start_with("https://forms.hackclub.com/t/")
      expect(url).to include("prefill_Your+Name=Ada+Lovelace")
      expect(url).to include("prefill_Login+Email=ada%40example.com")
      expect(url).to include("prefill_Transaction+Code=#{CGI.escape(hcb_code.hashid)}")
    end

    it "prefills a ledger item's page as the transaction code" do
      ledger_item = create(:ledger_item)

      url = helper.disputed_transactions_airtable_form_url(ledger_item:, user:)

      expect(url).to include("prefill_Transaction+Code=#{CGI.escape(ledger_item_url(ledger_item))}")
    end

    it "leaves the user fields out when no user is given" do
      url = helper.disputed_transactions_airtable_form_url(hcb_code: create(:hcb_code))

      expect(url).not_to include("prefill_Your+Name")
      expect(url).not_to include("prefill_Login+Email")
    end

    it "refuses both an HCB code and a ledger item" do
      expect { helper.disputed_transactions_airtable_form_url(hcb_code: create(:hcb_code), ledger_item: build(:ledger_item)) }.to raise_error(ArgumentError)
    end

    it "refuses neither" do
      expect { helper.disputed_transactions_airtable_form_url(user:) }.to raise_error(ArgumentError)
    end
  end
end
