# frozen_string_literal: true

require "rails_helper"

RSpec.describe Admin::Nav do
  describe "#sections" do
    it "returns a list of sections" do
      instance = described_class.new(page_title: "")

      expect(instance.sections).to be_a(Array)
      expect(instance.sections).to all(be_a(described_class::Section))
    end

    it "marks the appropriate section and item as active" do
      instance = described_class.new(page_title: "Donations")

      active_section = instance.sections.filter(&:active?).sole
      expect(instance.active_section).to eq(active_section)
      expect(active_section.name).to eq("Incoming Money")

      active_item = instance.sections.flat_map(&:items).filter(&:active?).sole
      expect(active_item.name).to eq("Donations")
    end

    it "performs basic normalization when finding the active item and section" do
      instance = described_class.new(page_title: "  donations")

      expect(instance.active_section.items.find(&:active?).name).to eq("Donations")
    end
  end

  describe described_class::Section do
    describe "#task_sum" do
      it "returns the sum of task counts, ignoring items without a count" do
        instance = described_class.new(
          name: "Dinosaurs",
          items: [
            Admin::Nav::Item.new(name: "Orpheus", path: "/", count: ->{ 11 }),
            Admin::Nav::Item.new(name: "Littlefoot", path: "/", count: ->{ 22 }),
            Admin::Nav::Item.new(name: "Barney", path: "/")
          ]
        )

        expect(instance.task_sum).to eq(33)
      end

      it "returns zero when no items have task counts" do
        instance = described_class.new(
          name: "Dinosaurs",
          items: [
            Admin::Nav::Item.new(name: "Barney", path: "/")
          ]
        )

        expect(instance.task_sum).to eq(0)
      end
    end
  end
end
