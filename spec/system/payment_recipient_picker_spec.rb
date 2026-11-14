# frozen_string_literal: true

require "rails_helper"

# The saved-recipient picker on the ACH, wire, and check forms. Picking a
# recipient is handled by the `payment-recipient` Stimulus controller, which
# hands the recipient to the form's Alpine scope via `payment-recipient:change`.
RSpec.describe "Saved payment recipient picker", type: :system do
  let(:event) { create(:event) }
  let(:manager) { create(:user) }

  before do
    create(:organizer_position, user: manager, event:, role: :manager, first_time: false)

    allow_any_instance_of(SessionsHelper)
      .to receive(:find_current_session)
      .and_return(create(:user_session, user: manager))
  end

  def pick(recipient, name_field:)
    find_field(name_field).click
    find("button.menu__action", text: recipient.name).click
  end

  def selected_recipient_id(form_scope)
    find("input[name='#{form_scope}[payment_recipient_id]']", visible: :hidden).value
  end

  describe "ACH transfer form" do
    let!(:recipient) do
      create(:payment_recipient, event:, payment_model: "AchTransfer",
                                 name: "Fiona Hackworth", email: "fiona@example.com",
                                 bank_name: "First Hack Bank", routing_number: "021000021",
                                 account_number: "123456789")
    end

    before { visit new_event_ach_transfer_path(event) }

    it "fills the form from a saved recipient and shows their details read-only" do
      pick(recipient, name_field: "ach_transfer_recipient_name")

      expect(page).to have_field("ach_transfer_recipient_name", with: "Fiona Hackworth")
      expect(selected_recipient_id("ach_transfer")).to eq(recipient.hashid)
      expect(page).to have_field(disabled: true, with: "fiona@example.com")
      expect(page).to have_field(disabled: true, with: "First Hack Bank")
      expect(page).to have_field(disabled: true, with: "•••••6789")
      expect(page).to have_no_field("ach_transfer_bank_name")
      expect(page).to have_no_field("ach_transfer_recipient_email")
    end

    it "forgets the saved recipient once the name is edited" do
      pick(recipient, name_field: "ach_transfer_recipient_name")
      expect(selected_recipient_id("ach_transfer")).to eq(recipient.hashid)

      find_field("ach_transfer_recipient_name").send_keys("e")

      expect(page).to have_field("ach_transfer_bank_name", with: "")
      expect(page).to have_field("ach_transfer_recipient_email", with: "")
      expect(selected_recipient_id("ach_transfer")).to eq("")
    end

    it "prefills the editable fields when editing a saved recipient's details" do
      pick(recipient, name_field: "ach_transfer_recipient_name")
      find("button[aria-label='Edit payment details']").click

      expect(page).to have_field("ach_transfer_bank_name", with: "First Hack Bank")
      expect(page).to have_field("ach_transfer_routing_number", with: "021000021")
      expect(page).to have_field("ach_transfer_recipient_email", with: "fiona@example.com")
      expect(selected_recipient_id("ach_transfer")).to eq(recipient.hashid)
    end
  end

  describe "wire form" do
    let!(:recipient) do
      create(:payment_recipient, event:, payment_model: "Wire",
                                 name: "Raviga Capital", email: "billing@raviga.example",
                                 bic_code: "DEUTDEFF", account_number: "DE89370400440532013000",
                                 address_line1: "1 Hauptstrasse", address_city: "Berlin",
                                 address_postal_code: "10115", recipient_country: "DE")
    end

    before { visit new_event_wire_path(event) }

    it "fills the form from a saved recipient and clears it once the name is edited" do
      pick(recipient, name_field: "wire_recipient_name")

      expect(page).to have_field("wire_recipient_name", with: "Raviga Capital")
      expect(selected_recipient_id("wire")).to eq(recipient.hashid)
      expect(page).to have_field(disabled: true, with: "DEUTDEFF")

      find_field("wire_recipient_name").send_keys("s")

      expect(page).to have_no_field(disabled: true, with: "DEUTDEFF")
      expect(selected_recipient_id("wire")).to eq("")
    end
  end

  describe "check form" do
    let!(:recipient) do
      create(:payment_recipient, event:, payment_model: "IncreaseCheck",
                                 name: "Orpheus Dino", email: "orpheus@example.com",
                                 address_line1: "15 Falls Road", address_city: "Shelburne",
                                 address_state: "VT", address_zip: "05482")
    end

    before { visit new_event_increase_check_path(event) }

    it "fills the form from a saved recipient and clears it once the name is edited" do
      pick(recipient, name_field: "increase_check_recipient_name")

      expect(page).to have_field("increase_check_recipient_name", with: "Orpheus Dino")
      expect(selected_recipient_id("increase_check")).to eq(recipient.hashid)
      expect(page).to have_field(disabled: true, with: "Shelburne")
      expect(page).to have_no_field("increase_check_address_city")

      find_field("increase_check_recipient_name").send_keys("s")

      expect(page).to have_field("increase_check_address_city", with: "")
      expect(selected_recipient_id("increase_check")).to eq("")
    end
  end
end
