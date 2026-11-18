# frozen_string_literal: true

module ReceiptService
  class Suggest
    include StripeAuthorizationsHelper

    # Weights and rules were tuned against a labelled sample of real receipts (see lib/tasks/receipt_pairings.rake).
    WEIGHTS = { amount: 200, card_last_four: 100, date: 150, merchant_zip_code: 50, merchant_name: 100 }.freeze
    UNKNOWN = 0.6 # a feature we couldn't compare counts as slightly worse than a coin flip
    SHOWN_DISTANCE = 60 # carousel and link modal cutoff; also the cap for stored rows
    STORED_PAIRINGS = 5
    EXACT_AMOUNT = 0.1 # amount values up to this are an exact match (0.1: same number, currency unclear)
    TIP_TOLERANCE = 0.25
    DISCOUNT_TOLERANCE = 0.1
    # Two charges at the same merchant this close together get mixed up too easily to auto-attach
    SIBLING_WINDOW = 1.hour
    COMPETITOR_DAYS = 10

    def initialize(receipt:)
      @receipt = receipt
      @extracted = receipt if receipt.data_extracted?
    end

    def run!
      return nil if user.nil?

      @extracted = ::ReceiptService::Extract.new(receipt: @receipt).run!
      # Receipts uploaded straight onto a transaction only need extraction (e.g. quick expense memos)
      return nil if @extracted.nil? || @receipt.receiptable.present?

      scored = rank(candidates)
      kept = scored.select { |s| s[:distance] <= SHOWN_DISTANCE }.first(STORED_PAIRINGS)

      if kept.any?
        rows = kept.map { |s| { receipt_id: @receipt.id, hcb_code_id: s[:hcb_code].id, distance: s[:distance], aasm_state: "unreviewed" } }
        # update_only keeps ignored/accepted/reversed pairings in their state on re-score
        SuggestedPairing.upsert_all(rows, unique_by: [:receipt_id, :hcb_code_id], update_only: [:distance])
      end
      @receipt.suggested_pairings.unreviewed.where.not(hcb_code_id: kept.map { |s| s[:hcb_code].id }).delete_all

      Turbo::StreamsChannel.broadcast_action_to([user, :receipt_bin], action: :refresh_suggested_pairings)

      auto_attach!(scored)

      scored
    end

    # Every candidate scored, best first.
    def rank(hcb_codes)
      hcb_codes.map { |hcb_code| score(hcb_code) }.sort_by { |s| s[:distance] }
    end

    def score(hcb_code)
      charged_at = (hcb_code.pt&.raw_pending_stripe_transaction&.created_at || hcb_code.date)&.in_time_zone
      # Signed days from the receipt's date to the charge: receipts are dated on or just before the charge
      gap = (charged_at.to_date - @extracted.extracted_date.to_date).to_i if charged_at && @extracted.extracted_date
      upload_gap = charged_at ? (@receipt.created_at - charged_at) / 1.day : Float::INFINITY
      merchant = hcb_code.stripe_merchant

      features = {
        amount: amount_value(hcb_code),
        card_last_four: card_last_four_value(hcb_code),
        date: date_value(gap),
        merchant_zip_code: zip_value(merchant),
        merchant_name: merchant_name_value(merchant),
      }
      # Without a date on the receipt, how soon it was uploaded after the charge is the next best thing
      values = features.merge(date: features[:date] || upload_gap_value(upload_gap))
      distance = WEIGHTS.sum { |name, weight| (values[name] || UNKNOWN) * weight } / WEIGHTS.values.sum.to_f * 100
      # Ties go to the charge closest to the upload; kept in the distance so stored pairings sort the same way
      distance += upload_gap.clamp(0, 365) / 365 * 0.01

      { hcb_code:, features:, distance:, gap:, upload_gap:, charged_at: }
    end

    # Auto-attach only when exactly one charge fits. A wrong attachment is much worse than a suggestion.
    def auto_attachable?(ranked)
      best, *others = ranked
      return false if best.nil? || !exact_amount?(best)
      return false if others.any? { |o| o[:features][:merchant_name] == 0 && o[:charged_at] && best[:charged_at] && (o[:charged_at] - best[:charged_at]).abs <= SIBLING_WINDOW }

      if best[:gap]&.between?(0, 1)
        others.none? { |o| exact_amount?(o) && o[:gap].abs <= COMPETITOR_DAYS }
      else
        # The receipt's date is missing or doesn't line up, so the amount has to single this charge out
        (best[:features][:merchant_name] == 0 || best[:features][:card_last_four] == 0) &&
          others.none? { |o| o[:features][:amount]&.<=(0.7) }
      end
    end

    private

    def auto_attach!(scored)
      return unless auto_attachable?(scored)

      best = scored.first
      # Don't auto-attach again after the user undid one for this receipt
      return if @receipt.suggested_pairings.reversed.exists?
      # The candidate list is memoized on the user, so another receipt may have just claimed this charge
      return if Receipt.exists?(receiptable: best[:hcb_code])

      @receipt.suggested_pairings.unreviewed.find_by(hcb_code: best[:hcb_code])&.mark_accepted!
    end

    def exact_amount?(scored)
      scored[:features][:amount]&.<=(EXACT_AMOUNT)
    end

    def amount_value(hcb_code)
      total = @extracted.extracted_total_amount_cents&.abs
      subtotal = @extracted.extracted_subtotal_amount_cents&.abs
      return nil if total.nil? && subtotal.nil?

      charge = hcb_code.stripe_merchant_amount || Money.from_cents(hcb_code.amount_cents.abs, Money.default_currency)
      cents = charge.cents
      receipt_currency = @extracted.extracted_currency.presence
      same_currency = receipt_currency.nil? || charge.currency.iso_code.casecmp?(receipt_currency)
      # Extraction reports hundredths, but currencies like JPY have no minor unit
      variants = ->(amount) { amount.nil? ? [] : [amount, (amount / 100 if charge.currency.subunit_to_unit == 1 && (amount % 100).zero?)].compact }
      totals, subtotals = variants.call(total), variants.call(subtotal)

      # "$" on a receipt could be several currencies, so an identical number in another currency still counts
      return same_currency ? 0 : 0.1 if totals.include?(cents)
      # Charged by a foreign merchant, receipt shows what it came to in USD
      return 0 if (receipt_currency.nil? || receipt_currency.casecmp?("USD")) && total == hcb_code.amount_cents.abs
      return same_currency ? 0.25 : 0.35 if subtotals.include?(cents)
      return 1 unless same_currency

      bases = (totals + subtotals).select(&:positive?)
      # A bit more than the receipt (tip added later) or a bit less (discount) says very little either way
      return 0.7 if bases.any? { |base| cents > base && cents <= base * (1 + TIP_TOLERANCE) }
      return 0.8 if bases.any? { |base| cents < base && cents >= base * (1 - DISCOUNT_TOLERANCE) }

      1
    end

    def card_last_four_value(hcb_code)
      receipt_last4 = @extracted.extracted_card_last4.presence
      card_last4 = hcb_code.card.try(:last_four).presence
      return nil if receipt_last4.nil? || card_last4.nil?

      # Mobile wallets print a device number, so a mismatch is common on correct matches (hence the lower weight)
      receipt_last4 == card_last4 ? 0 : 1
    end

    def date_value(gap)
      return nil if gap.nil?
      return 0 if gap.between?(0, 1) # charges are recorded in UTC, so often a day after the receipt's local date
      return 0.5 if gap == -1
      return 0.2 + (0.8 * gap.abs / 5.0) if gap.abs <= 5

      1
    end

    def upload_gap_value(days)
      return 0.3 if days <= 2
      return 0.5 if days <= 7
      return 0.7 if days <= 30

      0.9
    end

    def zip_value(merchant)
      stripe_zip = normalize_zip(merchant&.dig("postal_code"))
      receipt_zip = normalize_zip(@extracted.extracted_merchant_zip_code)
      # https://mapofzipcodes.com/blog/00000-zip-code
      # many merchants report 00000, which tells us nothing
      return nil if stripe_zip.nil? || receipt_zip.nil? || stripe_zip == "00000"

      # ZIP+4 and plain ZIP for the same place should match; numerically close ZIPs told us nothing
      stripe_zip, receipt_zip = [stripe_zip, receipt_zip].map { |zip| zip[/\A(\d{5})(-?\d{4})?\z/, 1] || zip }
      stripe_zip == receipt_zip ? 0 : 1
    end

    def normalize_zip(zip)
      zip.to_s.upcase.delete("^A-Z0-9-").presence
    end

    def merchant_name_value(merchant)
      receipt_name = @extracted.extracted_merchant_name.to_s.strip.downcase.presence
      return nil if receipt_name.nil? || merchant.nil? || merchant["name"].blank?

      stripe_name = humanized_merchant_name(merchant).downcase
      matches = stripe_name.include?(receipt_name) ||
                merchant["name"].downcase.include?(receipt_name) ||
                WhiteSimilarity.similarity(stripe_name, receipt_name) >= 0.5
      matches ? 0 : 1
    end

    def candidates
      user.transactions_missing_receipt.includes(canonical_pending_transactions: :raw_pending_stripe_transaction)
    end

    def user
      @receipt.user
    end

  end
end
