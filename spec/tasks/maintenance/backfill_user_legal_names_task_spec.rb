# frozen_string_literal: true

require "rails_helper"

RSpec.describe Maintenance::BackfillUserLegalNamesTask do
  # A row written before the legal name columns existed.
  def legacy_user(full_name)
    create(:user).tap { |user| user.update_columns(legal_first_name: nil, legal_last_name: nil, full_name:) }
  end

  it "only collects named users whose name hasn't been split" do
    legacy = legacy_user("Jane Elder")
    create(:user, legal_first_name: "Fiona", legal_last_name: "Hackworth")
    create(:user, legal_first_name: nil, legal_last_name: nil)
    legacy_user("")

    expect(described_class.collection).to contain_exactly(legacy)
  end

  it "splits the name without touching anything else", versioning: true do
    user = legacy_user("Dr. Juan de la Cruz")

    expect { described_class.process(user) }.not_to(change { [user.reload.full_name, user.updated_at, user.versions.count] })

    expect(user).to have_attributes(legal_first_name: "Juan", legal_last_name: "de la Cruz")
    expect(described_class.collection).to be_empty
  end

  it "backfills names that would no longer pass validation" do
    user = legacy_user("Zach Latta [Dev]")

    described_class.process(user)

    expect(user.reload).to have_attributes(legal_first_name: "Zach Latta", legal_last_name: "[Dev]")
  end

  it "does not overwrite a name the user saved after the task loaded them" do
    stale = legacy_user("Jane Elder")
    User.find(stale.id).update!(legal_first_name: "Janet", legal_last_name: "Smith")

    described_class.process(stale)

    expect(stale.reload).to have_attributes(legal_first_name: "Janet", legal_last_name: "Smith", full_name: "Janet Smith")
  end

  it "does not apply a stale parse when the legacy name changed after the task loaded the user" do
    stale = legacy_user("Jane Elder")
    User.where(id: stale.id).update_all(full_name: "Jane Smith")

    described_class.process(stale)

    expect(stale.reload).to have_attributes(legal_first_name: nil, legal_last_name: nil, full_name: "Jane Smith")
  end
end
