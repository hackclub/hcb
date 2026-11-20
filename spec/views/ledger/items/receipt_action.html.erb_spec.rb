# frozen_string_literal: true

require "rails_helper"

RSpec.describe "ledger/items/_receipt_action" do
  let(:items) { Array.new(2) { create(:canonical_pending_transaction, amount_cents: -10_00).local_hcb_code.reload.ledger_item } }

  it "gives each row a filtered direct-upload input and its own busy button inside its form", :aggregate_failures do
    html = items.map { |item| render(partial: "ledger/items/receipt_action", locals: { item: }) }.join
    forms = Nokogiri::HTML5.fragment(html).css("form")

    expect(forms.size).to eq(2)
    forms.each do |form|
      input = form.at_css("input[type=file]")
      expect(input["accept"]).to eq("image/*,image/heic,.pdf")
      expect(input["data-direct-upload-url"]).to be_present

      expect(form["data-controller"].split).to include("uploading")
      expect(form["data-action"]).to include("submit->uploading#start")
      button = form.at_css("##{form["data-uploading-button-value"]}")
      expect(button).to be_present
      expect(button.at_css("span").text.strip).to eq("Upload receipt")
    end
    expect(forms.map { |form| form["data-uploading-button-value"] }.uniq.size).to eq(2)
  end
end
