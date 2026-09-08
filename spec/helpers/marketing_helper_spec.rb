# frozen_string_literal: true

require "rails_helper"

RSpec.describe MarketingHelper, type: :helper do
  describe "#funder_comparison_rows" do
    # The comparison data drives a structured UI: status badges keyed on a fixed set, a per-vehicle
    # `detail` hash, and vehicle-tagged sources. A missing key or a typo'd status fails silently in
    # the view (a bad status renders no badge; a missing detail key renders a blank snippet), so
    # guard the shape here.
    it "every row is well-formed: values, valid statuses, complete detail, and tagged sources" do
      vehicle_keys = %i[hcb pf daf]

      helper.funder_comparison_rows.each do |row|
        label = row[:label]
        expect(label).to be_present, "a comparison row is missing :label"

        vehicle_keys.each do |vehicle|
          expect(row[vehicle]).to be_present, "#{label}: missing :#{vehicle} value"
        end

        [row[:pf_status], row[:daf_status]].each do |status|
          expect(%w[yes partial no]).to include(status), "#{label}: bad status #{status.inspect}"
        end

        detail = row[:detail]
        expect(detail).to be_a(Hash), "#{label}: :detail must be a per-vehicle hash"
        vehicle_keys.each do |vehicle|
          expect(detail[vehicle]).to be_present, "#{label}: :detail is missing the :#{vehicle} snippet"
        end

        (row[:sources] || []).each do |source|
          expect(source[:text]).to be_present, "#{label}: a source is missing :text"
          expect(source[:url]).to be_present, "#{label}: a source is missing :url"
          expect(%w[hcb pf daf]).to include(source[:for]), "#{label}: source :for must be hcb/pf/daf, got #{source[:for].inspect}"
        end
      end
    end
  end

  describe "#funder_faqs" do
    # Guards the "related" cross-links: they reference stable ids (not question wording), so this
    # catches a typo'd or stale id before it silently drops a link on the page.
    it "has unique ids, and every 'related' reference points to an existing FAQ id" do
      entries = helper.funder_faqs(stats: nil).flat_map { |group| group[:faqs] }
      ids = entries.filter_map { |entry| entry[:id] }
      related = entries.flat_map { |entry| entry[:related] || [] }

      expect(ids).to eq(ids.uniq), "FAQ ids must be unique"
      expect(related - ids).to be_empty, "every related id must match an existing FAQ id"
    end

    it "every group has a topic, and every question has a question and an answer" do
      helper.funder_faqs(stats: nil).each do |group|
        expect(group[:topic]).to be_present, "a FAQ group is missing :topic"
        expect(group[:faqs]).to be_present, "FAQ group #{group[:topic].inspect} has no questions"

        group[:faqs].each do |faq|
          expect(faq[:q]).to be_present, "a question in #{group[:topic].inspect} is missing :q"
          expect(faq[:a]).to be_present, "question #{faq[:q].inspect} is missing :a"
        end
      end
    end
  end
end
