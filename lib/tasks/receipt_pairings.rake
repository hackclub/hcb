# frozen_string_literal: true

# Read-only replay of ReceiptService::Suggest against receipts already linked to
# card charges. Usage: bin/rails "receipts:replay_pairings[500,90]" (sample size, days back)
namespace :receipts do
  desc "Replay receipt pairing suggestions against linked card-charge receipts (read-only)"
  task :replay_pairings, [:sample, :days] => :environment do |_, args|
    sample = (args[:sample] || 500).to_i
    days = (args[:days] || 90).to_i

    receipts = Receipt.where(receiptable_type: HcbCode.name, data_extracted: true)
                      .where.not(user_id: nil)
                      .where(created_at: days.days.ago..)
                      .order("RANDOM()").limit(sample).to_a
    accepted_ids = SuggestedPairing.accepted.where(receipt_id: receipts.map(&:id)).pluck(:receipt_id).to_set

    stats = Hash.new { |h, k| h[k] = Hash.new(0) }

    receipts.each do |receipt|
      truth = receipt.receiptable
      next unless truth&.card_charge?

      suggest = ReceiptService::Suggest.new(receipt:)
      # The uploader's card charges that existed, and had no receipt (or lost-receipt mark), when this one was uploaded
      others = HcbCode.card_locking_relevant_for_cardholder(receipt.user_id)
                      .where(created_at: ..receipt.created_at)
                      .where.not(id: truth.id)
                      .where("hcb_codes.marked_no_or_lost_receipt_at IS NULL OR hcb_codes.marked_no_or_lost_receipt_at > ?", receipt.created_at)
                      .where("NOT EXISTS (SELECT 1 FROM receipts r WHERE r.receiptable_type = 'HcbCode' AND r.receiptable_id = hcb_codes.id AND r.created_at < ?)", receipt.created_at)
                      .distinct

      ranked = suggest.rank([truth, *others])
      best = ranked.first
      right = best[:hcb_code].id == truth.id
      shown = best[:distance] <= ReceiptService::Suggest::SHOWN_DISTANCE

      s = stats[accepted_ids.include?(receipt.id) ? "linked via accepted suggestion (biased)" : "linked manually"]
      s[:receipts] += 1
      s[:top1] += 1 if right
      s[:top3] += 1 if ranked.first(3).any? { |r| r[:hcb_code].id == truth.id }
      s[:shown] += 1 if shown
      s[:shown_right] += 1 if shown && right
      s[right ? :right_auto : :wrong_auto] += 1 if suggest.auto_attachable?(ranked)
    end

    pct = ->(n, d) { d.zero? ? "-" : format("%.1f%%", 100.0 * n / d) }
    stats.each do |group, s|
      n = s[:receipts]
      puts "#{group}: #{n} receipts"
      puts "  top pick right:                    #{pct.call(s[:top1], n)}"
      puts "  true charge in top 3:              #{pct.call(s[:top3], n)}"
      puts "  suggestion shown / shown and right: #{pct.call(s[:shown], n)} / #{pct.call(s[:shown_right], n)}"
      puts "  auto-attach right / wrong:         #{s[:right_auto]} / #{s[:wrong_auto]} (wrong = #{pct.call(s[:wrong_auto], n)})"
    end
    puts "No linked card-charge receipts with extracted data found" if stats.empty?
  end
end
