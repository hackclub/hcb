# frozen_string_literal: true

require "rails_helper"

RSpec.describe Payroll::Invoice, type: :model do
  let(:event) { create(:event) }
  let(:payee) { create(:payee, event:) }
  let(:position) { create(:payroll_position, payee:, aasm_state: :onboarded) }

  def build_invoice(**attrs)
    position.invoices.build(name: "Engineering hours", amount_cents: 1_000, currency: position.currency, **attrs)
  end

  describe "manager notification" do
    it "emails the manager when a contractor submits their own invoice" do
      expect { build_invoice.save! }.to have_enqueued_mail(Payroll::InvoiceMailer, :submitted)
    end

    it "stays silent when an organizer uploads on the contractor's behalf" do
      expect { build_invoice(skip_manager_notification: true).save! }
        .not_to have_enqueued_mail(Payroll::InvoiceMailer, :submitted)
    end
  end
end
