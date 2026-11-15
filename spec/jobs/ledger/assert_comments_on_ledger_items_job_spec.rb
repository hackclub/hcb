# frozen_string_literal: true

require "rails_helper"

RSpec.describe Ledger::AssertCommentsOnLedgerItemsJob do
  def anomalies
    reported = []
    job = described_class.new
    allow(job).to receive(:report_anomaly) { |message| reported << message }
    job.perform_now

    reported
  end

  it "reports nothing when every comment on a code with a ledger item has moved to the item" do
    hcb_code = create(:hcb_code, ledger_item: create(:ledger_item))
    create(:comment, commentable: hcb_code.ledger_item)
    create(:comment, commentable: create(:hcb_code))

    expect(anomalies).to be_empty
  end

  it "reports comments left on a code that has a ledger item, once, with their count" do
    hcb_code = create(:hcb_code, ledger_item: create(:ledger_item))
    comments = create_list(:comment, 2, commentable: hcb_code)
    comments.last.destroy!

    expect(anomalies).to contain_exactly(a_string_including("2 comments", "Comment #{comments.map(&:id).join(", ")}"))
  end
end
