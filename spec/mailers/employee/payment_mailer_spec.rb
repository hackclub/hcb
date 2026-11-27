# frozen_string_literal: true

require "rails_helper"

RSpec.describe Employee::PaymentMailer, type: :mailer do
  describe "#approved" do
    def build_payment(user:)
      event = create(:event)
      employee = Employee.create!(event:, entity: user)
      employee.payments.create!(title: "October stipend", amount_cents: 250_00, reviewed_by: create(:user), aasm_state: "approved")
    end

    it "tells the employee the amount when they are paid by international wire" do
      allow(ColumnService).to receive(:get).and_return("country_code" => "GB")
      user = create(:user)
      user.personal_legal_entity.payout_methods.create!(default: true, details: build(:wire_payout_method_details))
      payment = build_payment(user:)

      mail = described_class.with(payment:).approved

      expect(mail.to).to eq([user.email])
      expect(mail.body.encoded).to include("international wire transfer of $250.00 USD")
    end

    it "tells the employee the amount when they are paid by ACH transfer" do
      user = create(:user)
      user.personal_legal_entity.payout_methods.create!(default: true, details: build(:ach_transfer_payout_method_details))
      payment = build_payment(user:)

      mail = described_class.with(payment:).approved

      expect(mail.body.encoded).to include("ACH transfer of $250.00")
    end
  end
end
