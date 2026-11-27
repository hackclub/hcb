# frozen_string_literal: true

require "rails_helper"

RSpec.describe ProcessColumnCheckDepositJob do
  let(:check_deposit) do
    CheckDeposit.create!(
      event: create(:event),
      created_by: create(:user),
      amount_cents: 25_00,
      front: { io: file_fixture("receipt.png").open, filename: "front.png", content_type: "image/png" },
      back: { io: file_fixture("receipt.png").open, filename: "back.png", content_type: "image/png" }
    )
  end

  it "flags the check deposit for manual submission when Column rejects the upload" do
    stub_request(:post, "https://api.column.com/transfers/checks/image/front").to_return(status: 400, body: { message: "bad image" }.to_json, headers: { "Content-Type" => "application/json" })
    allow(Rails.error).to receive(:unexpected)

    expect { described_class.perform_now(check_deposit:) }.to raise_error(described_class::ApiError, "bad image")

    expect(check_deposit.reload).to be_manual_submission_required
  end

  it "leaves a rejected check deposit alone when a retry runs" do
    check_deposit.update!(status: :rejected, rejection_reason: :poor_image_quality)
    front = stub_request(:post, "https://api.column.com/transfers/checks/image/front")

    described_class.perform_now(check_deposit:)

    expect(front).not_to have_been_requested
    expect(check_deposit.reload).to be_rejected
  end

  it "does nothing once the check deposit has been submitted" do
    check_deposit.update!(status: :submitted, column_id: "chkd_123")
    front = stub_request(:post, "https://api.column.com/transfers/checks/image/front")

    described_class.perform_now(check_deposit:)

    expect(front).not_to have_been_requested
    expect(check_deposit.reload).to be_submitted
  end
end
