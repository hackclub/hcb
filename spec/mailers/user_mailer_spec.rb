# frozen_string_literal: true

require "rails_helper"

RSpec.describe UserMailer do
  describe "#incomplete_payout_method" do
    it "tells the user which details are missing and links to payout settings" do
      user = create(:user, full_name: "Fiona Hackworth")
      payout_method = user.personal_legal_entity.payout_methods.create!(default: true, details: create(:wise_transfer_payout_method_details))
      payout_method.details.update!(recipient_birthday: nil)

      mail = described_class.incomplete_payout_method(user:, payout_method: payout_method.reload)

      expect(mail.to).to eq([user.email])
      expect(mail.body.encoded).to include("recipient&#39;s date of birth")
      expect(mail.body.encoded).to include("/my/settings/payouts")
    end
  end
end
