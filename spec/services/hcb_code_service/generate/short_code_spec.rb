# frozen_string_literal: true

require "rails_helper"

describe HcbCodeService::Generate::ShortCode do

  context "when run" do
    it "creates a conforming short_code" do
      10.times do
        short_code = described_class.new.run
        expect(short_code).to match(/[A-Z0-9]{5}/)
      end
    end
  end

  context "when short_code already exists" do
    it "regenerates a new one" do
      srand(42)
      old_hcb_code = create(:hcb_code)

      # Resetting the seed ensures that the next generated
      # short_code is the same as the previous one.
      srand(42)
      new_hcb_code = create(:hcb_code)

      expect(old_hcb_code.short_code).not_to eq(new_hcb_code.short_code)
    end
  end
end
