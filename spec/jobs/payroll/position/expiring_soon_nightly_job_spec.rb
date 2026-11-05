# frozen_string_literal: true

require "rails_helper"

RSpec.describe Payroll::Position::ExpiringSoonNightlyJob, type: :job do
  let(:payee) { create(:payee) }

  it "notifies managers of active contracts ending in a week" do
    create(:payroll_position, payee:, aasm_state: :onboarded, end_date: 7.days.from_now.to_date)

    expect { described_class.perform_now }
      .to have_enqueued_mail(Payroll::PositionMailer, :expiring_soon)
  end

  it "ignores contracts ending on other days" do
    create(:payroll_position, payee:, aasm_state: :onboarded, end_date: 8.days.from_now.to_date)
    create(:payroll_position, payee:, aasm_state: :onboarded, end_date: 6.days.from_now.to_date)

    expect { described_class.perform_now }
      .not_to have_enqueued_mail(Payroll::PositionMailer, :expiring_soon)
  end

  it "ignores contracts that aren't active" do
    create(:payroll_position, payee:, aasm_state: :onboarding, end_date: 7.days.from_now.to_date)
    create(:payroll_position, payee:, aasm_state: :terminated, end_date: 7.days.from_now.to_date)

    expect { described_class.perform_now }
      .not_to have_enqueued_mail(Payroll::PositionMailer, :expiring_soon)
  end
end
