# frozen_string_literal: true

require "rails_helper"

RSpec.describe Maintenance::FreezeDemoModeEventsTask do
  let!(:demo_event) { create(:event, :demo_mode) }
  let!(:frozen_demo_event) { create(:event, :demo_mode, financially_frozen: true) }
  let!(:normal_event) { create(:event) }
  let!(:frozen_normal_event) { create(:event, financially_frozen: true) }
  let!(:deleted_demo_event) do
    create(:event, :demo_mode).tap(&:destroy!)
  end

  it "only collects unfrozen demo organizations, including deleted ones" do
    expect(described_class.collection).to contain_exactly(demo_event, deleted_demo_event)
  end

  it "freezes demo organizations without changing other organizations or demo flags" do
    described_class.collection.each { |event| described_class.process(event) }

    expect(demo_event.reload).to be_financially_frozen
    expect(deleted_demo_event.reload).to be_financially_frozen
    expect(deleted_demo_event.deleted_at).to be_present
    expect(frozen_demo_event.reload).to be_financially_frozen
    expect(normal_event.reload).not_to be_financially_frozen
    expect(frozen_normal_event.reload).to be_financially_frozen
    expect([demo_event, frozen_demo_event, deleted_demo_event]).to all(be_demo_mode)
    expect([normal_event, frozen_normal_event]).to all(have_attributes(demo_mode: false))
    expect(described_class.collection).to be_empty
  end
end
