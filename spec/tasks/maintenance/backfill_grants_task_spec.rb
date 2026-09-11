# frozen_string_literal: true

require "rails_helper"

RSpec.describe Maintenance::BackfillGrantsTask do
  it "creates a grant pointing at the card grant for an un-backfilled invitation" do
    allow_any_instance_of(CardGrant).to receive(:transfer_money)
    card_grant = create(:card_grant, :pending_invite)
    card_grant.grant.destroy! # simulate a card grant that predates the Grant model

    expect { described_class.new.process(card_grant.reload) }.to change(Grant, :count).by(1)

    grant = card_grant.reload.grant
    expect(grant.grantable).to eq(card_grant)
    expect(grant).to have_attributes(event: card_grant.event, user: card_grant.user, sent_by: card_grant.sent_by)
  end

  it "is idempotent and skips a card grant that already has a grant" do
    allow_any_instance_of(CardGrant).to receive(:transfer_money)
    card_grant = create(:card_grant, :pending_invite)

    expect { described_class.new.process(card_grant) }.not_to change(Grant, :count)
  end

  it "points the backfilled grant at the report for a card grant accepted as a reimbursement" do
    event = create(:event, :with_positive_balance, plan_type: Event::Plan::HackClubAffiliate)
    create(:card_grant_setting, event:)
    card_grant = create(:card_grant, :pending_invite, event:, amount_cents: 10_00, allow_reimbursement_report: true)
    report = card_grant.convert_to_reimbursement_report!(accepted_by: card_grant.user)
    report.grant.destroy! # the converted grant now hangs off the report

    expect { described_class.new.process(card_grant.reload) }.to change(Grant, :count).by(1)

    expect(report.reload.grant.grantable).to eq(report)
  end
end
