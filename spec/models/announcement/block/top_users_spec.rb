# frozen_string_literal: true

require "rails_helper"

RSpec.describe Announcement::Block::TopUsers do
  describe "view paths" do
    it "uses spender-oriented partials" do
      expect(subject.partial).to eq("announcements/blocks/top_spenders")
      expect(subject.modal).to eq("announcements/modals/_top_spenders")
    end
  end
end
