# frozen_string_literal: true

require "rails_helper"

RSpec.describe PaymentMailer, type: :mailer do
  describe "#acceptance_reminder" do
    let(:payee) { create(:payee) }
    let(:payment) { create(:payment, payee:) }
    let!(:payout_method) do
      payee.legal_entity.payout_methods.create!(default: true, details: create(:wise_transfer_payout_method_details))
    end

    def reminder_body
      described_class.with(payment:).acceptance_reminder.body.encoded
    end

    it "asks for the payout method when it's missing a date of birth" do
      payout_method.details.update!(recipient_birthday: nil)

      expect(reminder_body).to include("Configure your payout method")
    end

    it "doesn't ask for a payout method that's ready" do
      expect(reminder_body).not_to include("Configure your payout method")
    end
  end
end
