# frozen_string_literal: true

require "rails_helper"

RSpec.describe Maintenance::BackfillSensitiveAhoyMessagesTask do
  def message(mailer)
    Ahoy::Message.create!(mailer:, subject: "subject", sent_at: 1.day.ago)
  end

  def run!
    task = described_class.new
    task.collection.each { |batch| task.process(batch) }
  end

  it "flags historical emails whose contents are secrets" do
    login_code = message("LoginCodeMailer#send_code")
    workspace_password = message("GSuiteAccountMailer#notify_user_of_reset")

    run!

    expect(login_code.reload).to be_sensitive
    expect(workspace_password.reload).to be_sensitive
  end

  it "flags email change emails sent under the pre-rename mailer name" do
    legacy = message("UserMailer#email_update_authorization")

    run!

    expect(legacy.reload).to be_sensitive
  end

  it "leaves ordinary emails alone" do
    ordinary = message("ReceiptBinMailer#bounce_success")
    workspace_verification = message("GSuiteAccountMailer#verify")

    run!

    expect(ordinary.reload).not_to be_sensitive
    expect(workspace_verification.reload).not_to be_sensitive
  end
end
