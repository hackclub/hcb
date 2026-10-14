# frozen_string_literal: true

require "rails_helper"

RSpec.describe HackClub::OrgChart do
  describe ".keys" do
    it "returns every key in the tree when no root is given" do
      keys = described_class.keys

      expect(keys).to include(:melanie, :gary, :lucy, :paul)
      expect(keys).to include("sierra", "manu", "sarvesh", "usr_MVt1m1")
    end

    it "returns the root and everyone below it, inclusive" do
      expect(described_class.keys(:gary)).to match_array(
        [:gary, "manu", "ruien", "luke", "samuelf", "usr_BetQLy", "usr_Jptm3Z", "usr_73tAe4"]
      )
    end

    it "does not include people outside the requested subtree" do
      expect(described_class.keys(:gary)).not_to include(:melanie, :lucy, "sean")
    end

    it "returns an empty array for an unknown root" do
      expect(described_class.keys(:nobody)).to eq([])
    end
  end

  describe ".user_ids" do
    it "resolves tree keys to the ids of existing users, skipping the rest" do
      gary = create(:user, email: "gary@hackclub.com")
      manu = create(:user, email: "manu@hackclub.com")
      outsider = create(:user, email: "someone-else@hackclub.com")

      ids = described_class.user_ids(:gary)

      expect(ids).to include(gary.id, manu.id)
      expect(ids).not_to include(outsider.id)
    end

    it "reports an unresolvable key rather than dropping it silently" do
      gary = create(:user, email: "gary@hackclub.com")
      stub_const("#{described_class}::TREE", { gary: ["ghost"] })

      expect(Rails.error).to receive(:report).with(
        an_instance_of(StandardError), context: { key: "ghost" }
      )

      expect(described_class.user_ids).to contain_exactly(gary.id)
    end
  end
end
