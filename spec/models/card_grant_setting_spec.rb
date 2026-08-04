# frozen_string_literal: true

require "rails_helper"

RSpec.describe CardGrantSetting, type: :model do
  it "expires grants after 90 days by default" do
    setting = create(:card_grant_setting)

    expect(setting.expiration_preference).to eq("90 days")
  end
end
