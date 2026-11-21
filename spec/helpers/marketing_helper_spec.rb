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

  describe "#ai_safety_faqs" do
    # The answers feed the JSON-LD as well as the page, so they stay plain text, and each one
    # opens with a direct answer that answer engines can quote.
    it "returns 13 plain-text FAQs in order, each opening with a direct answer" do
      faqs = helper.ai_safety_faqs(stats: { organizations: "8,200+" })

      expect(faqs.map { |f| f[:id] }).to eq(%w[
                                              need-a-501c3 funder-needs-sponsor how-fast pay-outside-us individuals exposure grant-agreement
                                              private policy-work own-nonprofit not-funded teenagers cost
                                            ])
      faqs.each do |faq|
        text = faq[:q] + faq[:a]
        expect(text).not_to match(/[<>]/), "#{faq[:id]} has HTML"
        expect(text).not_to include("\u2014", "!")
        expect(faq[:a]).to match(/\A(Yes|No|Not|Usually|\d)/), "#{faq[:id]} doesn't open with a direct answer"
      end
      expect(faqs.find { |f| f[:id] == "teenagers" }[:a]).to include("8,200+")
    end
  end

  describe "#ai_safety_ledger_rows" do
    it "has one grant, its 7% fee, and spending, with every icon present" do
      rows = helper.ai_safety_ledger_rows

      expect(rows.count { |r| r[:amount_cents].positive? }).to eq(1)

      # The example has to show the real fee on the grant, and the fee shouldn't read as the main cost.
      grant, fee = rows.first(2)
      expect(fee[:amount_cents]).to eq(-grant[:amount_cents] * 7 / 100)
      expect(rows.min_by { |r| r[:amount_cents] }).not_to eq(fee)

      # inline_icon raises on a missing icon, so check them all exist.
      rows.each { |r| expect(Rails.root.join("app/assets/images/icons/#{r[:icon]}.svg")).to exist }
    end
  end

  describe "#ai_safety_ledger_amount" do
    it "signs amounts with a plus or a true minus" do
      expect(helper.ai_safety_ledger_amount(850_000_00)).to eq("+$850,000.00")
      expect(helper.ai_safety_ledger_amount(-48_150_00)).to eq("\u2212$48,150.00")
    end
  end
end
