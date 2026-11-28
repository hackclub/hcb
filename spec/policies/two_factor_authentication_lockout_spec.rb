# frozen_string_literal: true

require "rails_helper"

# A member who ran out their organization's grace period to enable two-factor
# authentication keeps their position but loses access everywhere until they
# enable it. This walks the policies that used to check raw membership.
RSpec.describe "two-factor authentication lockout", type: :policy do
  let(:event) { create(:event, is_public: false) }
  let(:member) { create(:user) }

  before do
    create(:organizer_position, user: member, event:, role: :manager, is_signee: true)
    require_two_factor_authentication!(event, at: 8.days.ago)
  end

  it "keeps the position but denies the member everywhere" do
    expect(event.users).to include(member)

    expect(EventPolicy.new(member, event).edit?).to eq(false)
    expect(EventPolicy.new(member, event).toggle_two_factor_authentication_requirement?).to eq(false)

    canonical_transaction = create(:canonical_transaction, event:)
    expect(CanonicalTransactionPolicy.new(member, canonical_transaction).show?).to eq(false)

    allow(StripeService::Customer).to receive(:create).and_return(double(id: "cus_test"))
    invoice = create(:invoice, sponsor: create(:sponsor, event:))
    expect(InvoicePolicy.new(member, [invoice]).index?).to be_falsey

    invite = create(:organizer_position_invite, event:)
    expect(OrganizerPositionInvitePolicy.new(member, invite).index?).to eq(false)

    teammate = create(:organizer_position, event:)
    expect(OrganizerPositionPolicy.new(member, teammate).destroy?).to be_falsey

    comment = build(:comment, commentable: canonical_transaction.local_hcb_code, user: member)
    expect(CommentPolicy.new(member, comment).new?).to eq(false)
  end

  it "gives everything back once the member enables two-factor authentication" do
    member.update!(phone_number: "+18556254225")
    member.update!(phone_number_verified: true, use_two_factor_authentication: true)

    expect(EventPolicy.new(member, event).edit?).to eq(true)
    expect(EventPolicy.new(member, event).toggle_two_factor_authentication_requirement?).to eq(true)

    teammate = create(:organizer_position, event:)
    expect(OrganizerPositionPolicy.new(member, teammate).destroy?).to eq(true)
  end
end
