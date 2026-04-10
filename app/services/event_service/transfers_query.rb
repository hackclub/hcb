# frozen_string_literal: true

module EventService
  class TransfersQuery
    attr_reader :stats, :transfers

    def initialize(event:, filter: nil, search: nil, stats: false)
      @event = event
      @filter = filter
      @search = search
      @compute_stats = stats
    end

    def run
      build_collections
      compute_stats if @compute_stats
      apply_filter
      apply_search
      combine_and_sort
      self
    end

    private

    def build_collections
      @ach_transfers    = @event.ach_transfers
      @paypal_transfers = @event.paypal_transfers
      @wires            = @event.wires
      @wise_transfers   = @event.wise_transfers
      @checks           = @event.checks.includes(:lob_address)
      @increase_checks  = @event.increase_checks
      @disbursements    = @event.outgoing_disbursements.includes(:destination_event).not_card_grant_related
    end

    def compute_stats
      @stats = {
        deposited: @ach_transfers.deposited.sum(:amount) + @checks.deposited.sum(:amount) + @increase_checks.deposited.sum(:amount) + @disbursements.fulfilled.pluck(:amount).sum + @paypal_transfers.deposited.sum(:amount_cents) + @wires.deposited.map(&:usd_amount_cents).compact.sum + @wise_transfers.deposited.map(&:usd_amount_cents_or_quoted).compact.sum,
        in_transit: @ach_transfers.in_transit.sum(:amount) + @checks.in_transit_or_in_transit_and_processed.sum(:amount) + @increase_checks.in_transit.sum(:amount) + @disbursements.reviewing_or_processing.sum(:amount) + @paypal_transfers.approved.or(@paypal_transfers.pending).sum(:amount_cents) + @wires.approved.or(@wires.pending).map(&:usd_amount_cents).compact.sum + @wise_transfers.approved.or(@wise_transfers.pending).or(@wise_transfers.sent).map(&:usd_amount_cents_or_quoted).compact.sum,
        canceled: @ach_transfers.rejected.sum(:amount) + @checks.canceled.sum(:amount) + @increase_checks.canceled.sum(:amount) + @disbursements.rejected.sum(:amount) + @paypal_transfers.rejected.sum(:amount_cents) + @wires.rejected.map(&:usd_amount_cents).compact.sum + @wise_transfers.rejected.or(@wise_transfers.failed).map(&:usd_amount_cents_or_quoted).compact.sum
      }
    end

    def apply_filter
      case @filter
      when "in_transit"
        @ach_transfers    = @ach_transfers.in_transit
        @checks           = @checks.in_transit_or_in_transit_and_processed
        @increase_checks  = @increase_checks.in_transit
        @disbursements    = @disbursements.reviewing_or_processing
        @paypal_transfers = @paypal_transfers.approved.or(@paypal_transfers.pending)
        @wires            = @wires.approved.or(@wires.pending)
        @wise_transfers   = @wise_transfers.approved.or(@wise_transfers.pending).or(@wise_transfers.sent)
      when "deposited"
        @ach_transfers    = @ach_transfers.deposited
        @checks           = @checks.deposited
        @increase_checks  = @increase_checks.deposited
        @disbursements    = @disbursements.fulfilled
        @paypal_transfers = @paypal_transfers.deposited
        @wires            = @wires.deposited
        @wise_transfers   = @wise_transfers.deposited
      when "canceled"
        @ach_transfers    = @ach_transfers.rejected
        @checks           = @checks.canceled
        @increase_checks  = @increase_checks.canceled
        @disbursements    = @disbursements.rejected
        @paypal_transfers = @paypal_transfers.rejected
        @wires            = @wires.rejected
        @wise_transfers   = @wise_transfers.rejected.or(@wise_transfers.failed)
      end
    end

    def apply_search
      return if @search.blank?

      @ach_transfers   = @ach_transfers.search_recipient(@search)
      @checks          = @checks.search_recipient(@search)
      @increase_checks = @increase_checks.search_recipient(@search)
      @disbursements   = @disbursements.search_name(@search)
      @wires           = @wires.search_recipient(@search)
      @wise_transfers  = @wise_transfers.search_recipient(@search)
    end

    def combine_and_sort
      @transfers = (@increase_checks.to_a + @checks.to_a + @ach_transfers.to_a + @disbursements.to_a + @paypal_transfers.to_a + @wires.to_a + @wise_transfers.to_a).sort_by(&:created_at).reverse!
    end

  end
end
