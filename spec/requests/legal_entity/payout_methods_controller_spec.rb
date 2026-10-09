# frozen_string_literal: true

require "rails_helper"

# A rejected payout method re-renders users/edit_payout from this controller.
# The controller isn't under Users, so the page only renders while its partials
# are looked up by their full path (e.g. "users/settings_header").
RSpec.describe "LegalEntity::PayoutMethodsController", type: :request do
  let(:user) { create(:user) }
  let(:invalid_ach) { { account_number: "12345678", routing_number: "nope" } }

  before do
    session = create(:user_session, user:, verified: true, expiration_at: 1.hour.from_now)
    allow_any_instance_of(SessionsHelper).to receive(:find_current_session).and_return(session)
  end

  def expect_payout_settings_with_error
    expect(response).to have_http_status(:unprocessable_content)
    expect(response.body).to match(/<h1[^>]*>\s*Payouts\s*<\/h1>/)
    expect(response.body).to include("Routing number must be 9 digits")
  end

  describe "POST /my/settings/payouts/methods" do
    it "re-renders the payout settings with the error when the details are invalid" do
      expect {
        post payout_methods_path, params: {
          user: {
            payout_method_type: "LegalEntity::PayoutMethod::AchTransfer",
            payout_method_ach_transfer: invalid_ach
          }
        }
      }.not_to(change { LegalEntity::PayoutMethod.count })

      expect_payout_settings_with_error
    end
  end

  describe "PATCH /my/settings/payouts/methods/:id" do
    it "re-renders the payout settings with the error and keeps the existing method" do
      payout_method = user.personal_legal_entity.payout_methods.create!(
        default: true,
        details: LegalEntity::PayoutMethod::AchTransfer.new(account_number: "12345678", routing_number: "021000021")
      )

      patch payout_method_path(payout_method), params: { user: { payout_method_ach_transfer: invalid_ach } }

      expect_payout_settings_with_error
      expect(payout_method.reload).not_to be_archived
    end
  end
end
