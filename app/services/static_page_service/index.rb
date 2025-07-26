# frozen_string_literal: true

module StaticPageService
  class Index
    def initialize(current_user:)
      @current_user = current_user
    end

    def redirect_to_first_event?
      !auditor? && events.count == 1 && invites.count == 0
    end

    def events
      @current_user.events.reorder("organizer_positions.sort_index ASC", "events.id ASC").includes(:stripe_cards, organizer_positions: :user)
    end

    def organizer_positions
      @current_user.organizer_positions.includes(:event).order(sort_index: :asc, event_id: :asc)
    end

    def invites
      @current_user.organizer_position_invites.pending
    end

    # Counts

    def checks_count
      Check.in_transit.count
    end

    def ach_transfers_count
      AchTransfer.pending.count
    end

    def fee_reimbursements_count
      FeeReimbursement.unprocessed.count
    end

    def g_suites_needs_ops_review_count
      GSuite.needs_ops_review.count
    end

    def organizer_position_deletion_requests_count
      OrganizerPositionDeletionRequest.under_review.count
    end

    def transactions_count
      Transaction.needs_action.count
    end

    def disbursements_count
      Disbursement.pending.count
    end

    private

    def auditor?
      @current_user.auditor?
    end

  end
end
