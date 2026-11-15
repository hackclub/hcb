# frozen_string_literal: true

require "rails_helper"

RSpec.describe Metric::User::MostInteractedWith do
  it "counts comments on a transaction the user requested, whether on its HCB code or its ledger item" do
    requester = create(:user)
    commenter = create(:user)
    disbursement = create(:disbursement, requested_by: requester)
    hcb_code = disbursement.outgoing_disbursement.local_hcb_code
    hcb_code.update!(ledger_item: create(:ledger_item))
    create(:comment, :legacy_on_hcb_code, commentable: hcb_code, user: commenter, created_at: Date.new(Metric.year, 6, 1))
    create(:comment, commentable: hcb_code.ledger_item, user: commenter, created_at: Date.new(Metric.year, 6, 2))

    expect(described_class.new(subject: requester).calculate).to eq(name: commenter.name, id: commenter.id, comments: 2)
  end
end
