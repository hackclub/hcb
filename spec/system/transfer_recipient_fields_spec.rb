# frozen_string_literal: true

require "rails_helper"

# The wire and Wise forms ask for different fields depending on the recipient's
# country, the currency and the account type. Fields that don't apply are
# hidden and disabled by the `state-switch` controller, so they're neither
# submitted nor validated.
RSpec.describe "Transfer recipient fields", type: :system do
  let(:event) { create(:event) }
  let(:manager) { create(:user) }

  before do
    create(:organizer_position, user: manager, event:, role: :manager, first_time: false)

    allow_any_instance_of(SessionsHelper)
      .to receive(:find_current_session)
      .and_return(create(:user_session, user: manager))
  end

  describe "wire form" do
    before { visit new_event_wire_path(event) }

    it "asks for the selected country's details" do
      select "India", from: "wire_recipient_country"

      expect(page).to have_field("wire_local_bank_code_in")
      expect(page).to have_no_field("wire_local_bank_code_ca")
      expect(page).to have_field("wire_local_bank_code_ca", visible: :hidden, disabled: true)

      select "Canada", from: "wire_recipient_country"

      expect(page).to have_field("wire_local_bank_code_ca")
      expect(page).to have_field("wire_local_bank_code_in", visible: :hidden, disabled: true)
    end

    it "points domestic transfers to ACH" do
      select "United States", from: "wire_recipient_country"

      expect(page).to have_text("Use ACH for domestic US transfers")
      expect(page).to have_no_field("wire_bic_code")
      expect(page).to have_button("Send wire", disabled: true)

      select "India", from: "wire_recipient_country"

      expect(page).to have_no_text("Use ACH for domestic US transfers")
      expect(page).to have_field("wire_bic_code")
      expect(page).to have_button("Send wire", disabled: false)
    end
  end

  describe "Wise form" do
    before { visit new_event_wise_transfer_path(event) }

    it "asks for the selected currency's and account type's details" do
      expect(page).to have_no_field("wise_transfer_account_holder_cad")

      select "CAD", from: "wise_transfer_currency"

      expect(page).to have_field("wise_transfer_institution_number_cad")
      expect(page).to have_no_field("wise_transfer_interac_email_cad")

      select "Interac e-Transfer", from: "wise_transfer_account_type_cad"

      expect(page).to have_field("wise_transfer_interac_email_cad")
      expect(page).to have_field("wise_transfer_institution_number_cad", visible: :hidden, disabled: true)
      expect(page).to have_text("Wise transfers via Interac are currently not supported")
    end
  end
end
