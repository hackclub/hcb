# frozen_string_literal: true

module CardLocking
  # All card-locking behavior for a cardholder (User): the lock decision, trust
  # assessment, and the outstanding/overdue queries.
  #
  # All of these intentionally consider every cardholder the user owns
  # (stripe_cardholders has no DB uniqueness on user_id), so the lock decision can
  # never diverge from the notification/candidate set.
  module CardholderBehavior
    extend ActiveSupport::Concern

    class_methods do
      def card_locking_candidates
        candidate_user_ids = HcbCode.card_locking_candidates.select("DISTINCT stripe_cardholders.user_id")

        where(cards_locked: true).or(where(id: candidate_user_ids)).distinct
      end
    end

    def cards_should_lock?(now: Time.current)
      return false if card_locking_suppressed?(now:)

      card_locking_has_overdue_charge?(now:)
    end

    def last_settled_charge_at
      return nil unless stripe_cardholder

      HcbCode.card_locking_relevant_for_cardholder(id).maximum(:receipt_settled_at)
    end

    # Trusted iff on-time rate >= 80% over the last 6 months AND the most recent
    # determined charge was on time. Determined = resolved, or overdue-and-unresolved.
    # Not-yet-due unresolved charges are excluded. Constant query count regardless
    # of history size (one pluck of scalars).
    def receipt_trusted?(now: Time.current)
      return false unless stripe_cardholder

      rows = HcbCode.card_locking_relevant_for_cardholder(id)
                    .where("hcb_codes.receipt_settled_at >= ?", CardLocking::TRUST_LOOKBACK.ago)
                    .distinct
                    .pluck(:id, :receipt_settled_at, :receipt_due_at, :receipt_resolved_at)

      considered = rows.filter_map do |id, settled, due, resolved|
        next if settled.nil?

        if resolved
          # Resolved pre-enforcement charges never got a real receipt_due_at, so
          # synthesize a 7-day due date from settled_at. This lets a pre-enforcement
          # receipt upload still count as on time and earn trust.
          [id, settled, resolved <= (due || settled + CardLocking::RECEIPT_DUE_WINDOW)]
        elsif due && due <= now
          [id, settled, false] # overdue, unresolved
        end
        # not-yet-due unresolved -> filtered out (block returns nil)
      end
      return false if considered.empty?

      on_time_count = considered.count { |_id, _settled, on_time| on_time }
      # Deterministic recency: break settled_at ties by id.
      most_recent = considered.max_by { |id, settled, _on_time| [settled, id] }

      CardLocking::TrustAssessment.new(
        on_time_count:, considered_count: considered.size, most_recent_on_time: most_recent[2]
      ).trusted?
    end

    def card_locking_has_overdue_charge?(now: Time.current)
      card_locking_overdue_charges(now:).exists?
    end

    # Any outstanding charge within WARNING_LEAD_TIME of its deadline (or already
    # past it). Gates the pre-lock warning so fresh charges don't trigger it.
    def card_locking_has_approaching_charge?(now: Time.current)
      card_locking_overdue_charges(now: now + CardLocking::WARNING_LEAD_TIME).exists?
    end

    def card_locking_suppressed?(now: Time.current)
      card_locking_suppressed_until.present? && card_locking_suppressed_until > now
    end

    # Overdue charges: past deadline and still unresolved.
    #
    # The persisted receipt_due_at / receipt_resolved_at columns are the primary
    # signal (partial-index-friendly). card_locking_candidates adds the live "still
    # missing a receipt" join (no attached receipts row, marked_no_or_lost_receipt_at
    # NULL) as a self-healing safety net: a charge whose receipt was attached via a
    # path that bypassed the materializer (bulk insert, raw import, rolled-back
    # callback) can't stay wrongly overdue forever. The extra join does not stop the
    # partial index on receipt_due_at from being used for the persisted predicate.
    def card_locking_overdue_charges(now: Time.current)
      return HcbCode.none unless stripe_cardholder

      HcbCode.card_locking_candidates
             .where(stripe_cardholders: { user_id: id })
             .receipt_overdue(now)
             .distinct
    end

    # All outstanding (unresolved, enforcement-era) charges for this cardholder.
    def card_locking_outstanding_charges
      return HcbCode.none unless stripe_cardholder

      HcbCode.card_locking_candidates
             .where(stripe_cardholders: { user_id: id })
             .distinct
    end

    def card_locking_outstanding_count
      card_locking_outstanding_charges.count
    end
  end
end
