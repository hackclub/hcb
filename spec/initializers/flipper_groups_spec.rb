# frozen_string_literal: true

require "rails_helper"

# Verifies the groups registered in config/initializers/flipper_groups.rb are
# wired to FlipperGroups and correctly unwrap the Flipper actor end to end.
RSpec.describe "flipper_groups initializer" do
  let(:outsider) { create(:user, email: "outsider@example.com") }

  # A distinct feature per group keeps enable_group state from leaking between
  # examples.
  def gate(group, actor)
    feature = :"group_wiring_#{group}"
    Flipper.enable_group(feature, group)
    Flipper.enabled?(feature, actor)
  end

  it "gates a feature on the :hcb_team group" do
    melanie = create(:user, email: "melanie@hackclub.com")

    expect(gate(:hcb_team, melanie)).to be(true)
    expect(gate(:hcb_team, outsider)).to be(false)
  end

  it "gates a feature on the :hcb_engineers group" do
    engineer = create(:user, email: "gary@hackclub.com")

    expect(gate(:hcb_engineers, engineer)).to be(true)
    expect(gate(:hcb_engineers, outsider)).to be(false)
  end

  it "gates a feature on the :hackclub_emails group" do
    staff = create(:user, email: "staff@hackclub.com")

    expect(gate(:hackclub_emails, staff)).to be(true)
    expect(gate(:hackclub_emails, outsider)).to be(false)
  end

  it "gates a feature on the :admins_and_auditors group" do
    auditor = create(:user, access_level: :auditor)

    expect(gate(:admins_and_auditors, auditor)).to be(true)
    expect(gate(:admins_and_auditors, outsider)).to be(false)
  end

  it "gates a feature on the :hq_descendant_users group" do
    admin = create(:user, :make_admin)

    expect(gate(:hq_descendant_users, admin)).to be(true)
    expect(gate(:hq_descendant_users, outsider)).to be(false)
  end

  it "gates a feature on the :hq_descendant_organizations group with an Event actor" do
    hq_org = create(:event)
    other_org = create(:event)
    stub_const("FlipperGroups::HQ_ROOT_EVENT_IDS", [hq_org.id])

    expect(gate(:hq_descendant_organizations, hq_org)).to be(true)
    expect(gate(:hq_descendant_organizations, other_org)).to be(false)
  end
end
