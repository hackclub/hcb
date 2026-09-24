# frozen_string_literal: true

require "rails_helper"

RSpec.describe Payroll::Position::OnboardingReminderJob, type: :job do
  let(:payee) { create(:payee) }
  let(:position) { create(:payroll_position, payee:, aasm_state: :onboarding) }

  it "reminds an onboarding contractor who still has steps outstanding" do
    allow(position).to receive(:contractor_onboarding_incomplete?).and_return(true)

    expect { described_class.perform_now(position) }
      .to have_enqueued_mail(Payroll::PositionMailer, :onboarding_reminder)
  end

  it "stays quiet once the contractor has finished their steps" do
    allow(position).to receive(:contractor_onboarding_incomplete?).and_return(false)

    expect { described_class.perform_now(position) }
      .not_to have_enqueued_mail(Payroll::PositionMailer, :onboarding_reminder)
  end

  it "stays quiet while the position is still under review by HCB" do
    under_review = create(:payroll_position, payee:)
    allow(under_review).to receive(:contractor_onboarding_incomplete?).and_return(true)

    expect { described_class.perform_now(under_review) }
      .not_to have_enqueued_mail(Payroll::PositionMailer, :onboarding_reminder)
  end

  it "skips managed contractors, whose onboarding the org handles for them" do
    allow(position).to receive(:contractor_onboarding_incomplete?).and_return(true)
    allow(payee).to receive(:managed?).and_return(true)
    allow(position).to receive(:payee).and_return(payee)

    expect { described_class.perform_now(position) }
      .not_to have_enqueued_mail(Payroll::PositionMailer, :onboarding_reminder)
  end
end
