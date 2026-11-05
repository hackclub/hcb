# frozen_string_literal: true

require "rails_helper"

RSpec.describe HcbCodeHelper, type: :helper do
  let(:event) { create(:event) }
  let(:hcb_code) { create(:canonical_pending_transaction, event:, amount_cents: -1_00).local_hcb_code }

  describe "#short_attach_receipt_url" do
    it "points at the short receipt link route" do
      expect(helper.short_attach_receipt_url(hcb_code)).to start_with(
        "#{Rails.application.routes.url_helpers.root_url}r/#{hcb_code.hashid}/"
      )
    end

    it "is meaningfully shorter than the long signed url" do
      expect(helper.short_attach_receipt_url(hcb_code).length).to be < 100
      expect(helper.short_attach_receipt_url(hcb_code).length).to be < helper.attach_receipt_url(hcb_code).length
    end
  end
end
