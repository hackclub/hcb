# frozen_string_literal: true

module SetLedgerFilters
  extend ActiveSupport::Concern

  # Params that narrow a ledger: `query` for the new ledger, the rest for the
  # classic transactions page. `q` is excluded because the search box renders
  # outside the filter menu; `subledger` because it picks which ledger to show
  # rather than filtering one.
  FILTER_PARAMS = %i[
    query tag user type start end minimum_amount maximum_amount
    missing_receipts merchant direction category
  ].freeze

  TYPE_PREDICATES = {
    "ach_transfer"           => { "$eq": "AchTransfer" },
    "mailed_check"           => { "$in": ["Check", "IncreaseCheck"] },
    "hcb_transfer"           => { "$in": ["Disbursement::Outgoing", "Disbursement::Incoming"] },
    "card_charge"            => { "$eq": "CardCharge" },
    "check_deposit"          => { "$eq": "CheckDeposit" },
    "donation"               => { "$eq": "Donation" },
    "invoice"                => { "$eq": "Invoice" },
    "fiscal_sponsorship_fee" => { "$eq": "BankFee" },
    "reimbursement"          => { "$eq": "Reimbursement::ExpensePayout" },
    "wire"                   => { "$eq": "Wire" },
    "paypal_transfer"        => { "$eq": "PaypalTransfer" },
    "wise_transfer"          => { "$eq": "WiseTransfer" }
  }.freeze

  # Zero-amount items are subject to a status allowlist.
  VISIBLE = {
    "$or": [
      { amount_cents: { "$ne": 0 } },
      { status: { "$in": ["settled", "pending", "reversed"] } }
    ]
  }.freeze

  DIRECTION_PREDICATES = {
    "expenses" => { "$lt" => 0 },
    "revenue"  => { "$gt" => 0 }
  }.freeze

  MISSING_RECEIPTS = {
    "receipt_count"                => 0,
    "receipt_required"             => true,
    "marked_no_or_lost_receipt_at" => nil
  }.freeze

  included do
    private

    # Filtering is what makes a transparent organization expensive to read
    # anonymously: every combination is a separate, uncacheable trip through the
    # transaction engines. Anonymous readers get the unfiltered page.
    #
    # Runs before the filters are resolved, because resolving them is most of the
    # cost: `Event#merchants` alone loads every transaction for the organization.
    def reject_disabled_filters
      @ledger_filters_disabled = !signed_in?
      return unless @ledger_filters_disabled
      return if FILTER_PARAMS.none? { |name| params[name].present? }

      render plain: "Invalid parameters. Please try again", status: :bad_request
    end

    def set_ledger_filters
      # The search query name was historically `search`. It has since been renamed
      # to `q`. This following line retains backwards compatibility.
      params[:q] ||= params[:search]

      reject_disabled_filters
      return if performed?

      @ledger_filters = parse_ledger_filters

      # Chips and menus only recognize the shapes the filter menu writes; anything
      # else is listed as a custom filter.
      @tag = @event.tags.find_by(id: @ledger_filters["tag"]) if @ledger_filters["tag"].is_a?(Integer)
      @type = TYPE_PREDICATES.find { |_, predicate| predicate.stringify_keys == @ledger_filters["linked_object_type"] }&.first
      @start_date, @end_date = ledger_filter_dates
      @minimum_amount, @maximum_amount = ledger_filter_amounts
      @missing_receipts = @ledger_filters >= MISSING_RECEIPTS
      @merchant = @ledger_filters["merchant"] if @ledger_filters["merchant"].is_a?(String)
      @direction = DIRECTION_PREDICATES.key(@ledger_filters["amount_cents"])
      @category = TransactionCategory.find_by(slug: @ledger_filters["category"]) if @ledger_filters["category"].is_a?(String)

      @ledger = @event.ledger
      @ledgers = if @use_card_grant_ledgers
                   Ledger.where(card_grant: @event.card_grants)
                 else
                   [@ledger]
                 end

      author_ids = Ledger::Item
                   .where(id: Ledger::Mapping.where(ledger: @ledgers).select(:ledger_item_id))
                   .where.not(author_id: nil)
                   .distinct
                   .select(:author_id)
      organizer_ids = @event.users.select(:id)
      @users = User.where("users.id IN (#{author_ids.to_sql} UNION #{organizer_ids.to_sql})")
                   .with_attached_profile_picture
                   .order(Arel.sql("CONCAT(preferred_name, full_name) ASC"))

      @user = @users.find_by(slug: @ledger_filters["author"]) if @ledger_filters["author"].is_a?(String)

      if @merchant
        merchant = @event.merchants.find { |merchant| merchant[:id] == @merchant }

        @merchant_name = merchant.present? ? merchant[:name] : "Merchant #{@merchant}"
      end

      recognized_fields = {
        "tag"                   => @tag,
        "author"                => @user,
        "linked_object_type"    => @type,
        "amount_cents"          => @direction,
        "absolute_amount_cents" => @minimum_amount || @maximum_amount,
        "datetime"              => @start_date || @end_date,
        "category"              => @category,
        "merchant"              => @merchant
      }.compact.keys
      recognized_fields += MISSING_RECEIPTS.keys if @missing_receipts
      @custom_ledger_filters = @ledger_filters.except(*recognized_fields)
    end

    # The viewer's filters are one clause of the query, so they can narrow the
    # ledger but never lift the filters the page applies on top of them.
    def ledger_query
      query = [@ledger_filters, VISIBLE]
      query << { memo: { "$search": params[:q] } } if params[:q].present?

      Ledger::Query.new({ "$and": query })
    end

    def parse_ledger_filters
      return {} if params[:query].blank?

      filters = JSON.parse(params[:query]) if params[:query].is_a?(String)
      raise Ledger::Query::Error.new("Query must be a JSON object") unless filters.is_a?(Hash)

      filters
    rescue JSON::ParserError => e
      raise Ledger::Query::Error.new("Query must be valid JSON: #{e.message}")
    end

    # A range filter as the filter menu writes it: an object of only these bounds.
    def ledger_filter_range(field, bounds)
      range = @ledger_filters[field]
      range if range.is_a?(Hash) && range.present? && (range.keys - bounds).empty?
    end

    # The date filter writes whole days: `$gte` the first, `$lt` the day after the last.
    def ledger_filter_dates
      dates = ledger_filter_range("datetime", %w[$gte $lt])
      return unless dates&.values&.all?(String)

      start_date, end_date = dates.values_at("$gte", "$lt").map { |date| date && Date.strptime(date, "%Y-%m-%d") }
      [start_date, end_date&.prev_day]
    rescue Date::Error
      nil
    end

    def ledger_filter_amounts
      amounts = ledger_filter_range("absolute_amount_cents", %w[$gte $lte])
      return unless amounts&.values&.all?(Integer)

      amounts.values_at("$gte", "$lte").map { |cents| cents && Money.new(cents) }
    end

  end

end
