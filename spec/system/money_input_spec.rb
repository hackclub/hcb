# frozen_string_literal: true

require "rails_helper"

RSpec.describe "Money inputs", type: :system do
  include SystemSessionSupport

  let(:user) { create(:user, phone_number: "+18556254225") }
  let(:event) { create(:event, organizers: [user]) }
  let(:amount) { find_field("ach_transfer[amount_money]") }

  before do
    sign_in(user)
    visit new_event_ach_transfer_path(event)
  end

  it "cuts amounts to cents as they are typed instead of rounding" do
    amount.fill_in(with: "12.999")

    expect(amount.value).to eq("12.99")
  end

  it "pads whole and partial amounts to cents on blur" do
    amount.fill_in(with: "5")
    find("body").click
    expect(amount.value).to eq("5.00")

    amount.fill_in(with: "0.5")
    find("body").click
    expect(amount.value).to eq("0.50")
  end
end
