# frozen_string_literal: true

require "rails_helper"

RSpec.describe "Copy to clipboard", type: :system do
  include SystemSessionSupport

  let(:user) { create(:user, phone_number: "+18556254225") }
  let(:copy_button) { find("button[aria-label='Copy number']") }

  def copied_texts = evaluate_script("window.copiedTexts")

  before do
    create(:event, organizers: [user])
    sign_in(user)
    visit my_reimbursements_path
    # Headless Chrome can't read the clipboard back, so record what the page writes to it
    execute_script("window.copiedTexts = []; navigator.clipboard.writeText = text => (copiedTexts.push(text), Promise.resolve())")
  end

  it "copies the button's value and confirms it, then restores the label" do
    copy_button.click

    expect(copied_texts).to eq(["+1-864-548-4225"])
    expect(page).to have_css("button[aria-label='Copied!']")
    expect(page).to have_css("button[aria-label='Copy number']", wait: 3)
  end

  it "copies the right value when a page has several copy buttons" do
    find("button[aria-label='Copy email address']").click

    expect(copied_texts).to eq(["reimburse@hcb.gg"])
  end
end
