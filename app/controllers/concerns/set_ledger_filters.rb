# frozen_string_literal: true

module SetLedgerFilters
  extend ActiveSupport::Concern

  # Params that narrow a ledger. `q` is excluded because the search box renders
  # outside the filter menu; `subledger` because it picks which ledger to show
  # rather than filtering one.
  FILTER_PARAMS = %i[
    tag user type start end minimum_amount maximum_amount
    missing_receipts merchant direction category
  ].freeze

  included do
    helper_method :ledger_filtered?, :ledger_filter_params, :merchant_name

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

      if params[:tag]
        @tag = Tag.find_by(event_id: @event.id, label: params[:tag])
      end

      @type = params[:type].presence
      # A date that doesn't parse narrows nothing, like a tag that doesn't exist.
      @start_date = parse_date_param(params[:start])
      @end_date = parse_date_param(params[:end])
      @minimum_amount = params[:minimum_amount].presence ? Money.from_amount(params[:minimum_amount].to_f) : nil
      @maximum_amount = params[:maximum_amount].presence ? Money.from_amount(params[:maximum_amount].to_f) : nil
      @missing_receipts = params[:missing_receipts].present?
      @merchant = params[:merchant].presence
      @direction = params[:direction].presence
      @category = TransactionCategory.find_by(slug: params[:category])

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

      @user = @users.friendly.find(params[:user], allow_nil: true) if params[:user]
    end

    # The merchant filter's display name. Resolved on demand rather than with
    # the other filters: finding it means loading every merchant the
    # organization has ever paid, and only the filter chip on the page needs
    # it. An export filtered by merchant needs only the id.
    def merchant_name
      return @merchant_name if defined?(@merchant_name)

      merchant = @event.merchants.find { |candidate| candidate[:id] == @merchant }

      @merchant_name = merchant.present? ? merchant[:name] : "Merchant #{@merchant}"
    end

    def ledger_query
      Ledger::Query.new({ "$and": ledger_filter_predicates + [visibility_predicate] })
    end

    # The predicates the user's filters add to the query, and nothing else.
    # Built from the resolved filters, not the raw params: `?tag=nonexistent`
    # resolves to no tag and so adds no predicate, and the ledger it produces
    # is the whole ledger.
    def ledger_filter_predicates
      return @ledger_filter_predicates if defined?(@ledger_filter_predicates)

      query = []

      query << { memo: { "$search": params[:q] } } if params[:q].present?

      if @direction.present? || @minimum_amount.present? || @maximum_amount.present?
        if @direction == "revenue"
          query << { amount_cents: { "$gt": 0 } }
        elsif @direction == "expenses"
          query << { amount_cents: { "$lt": 0 } }
        end

        if @minimum_amount.present?
          query << { "$or": [{ amount_cents: { "$gte": @minimum_amount.cents } }, { amount_cents: { "$lte": -@minimum_amount.cents } }] }
        end

        if @maximum_amount.present?
          # Multiple operators on one field are AND-combined: |amount| <= max
          query << { amount_cents: { "$lte": @maximum_amount.cents, "$gte": -@maximum_amount.cents } }
        end
      end

      if @missing_receipts
        query << { receipt_count: { "$eq": 0 } }
        query << { receipt_required: { "$eq": true } }
        query << { marked_no_or_lost_receipt_at: { "$eq": nil } }
      end

      query << { datetime: { "$gte": @start_date } } if @start_date.present?
      # Whole-day inclusive end bound, matching the old transactions page
      query << { datetime: { "$lt": @end_date.next_day } } if @end_date.present?

      query << { author: { "$eq": @user&.slug || params[:user] } } if params[:user].present?

      query << { tag: { "$eq": @tag.id } } if @tag.present?
      query << { category: { "$eq": @category.slug } } if @category.present?
      query << { merchant: { "$eq": @merchant } } if @merchant.present?

      if @type.present?
        linked_object_type = {
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
        }[@type]

        query << { linked_object_type: }
      end

      @ledger_filter_predicates = query
    end

    # Amount trumps status: an item that moved any non-zero amount should
    # always render (e.g. a declined/failed transaction that still posted a
    # partial charge), regardless of its status. Only zero-amount items are
    # subject to the status allowlist.
    def visibility_predicate
      {
        "$or": [
          { amount_cents: { "$ne": 0 } },
          { status: { "$in": ["settled", "pending", "reversed"] } }
        ]
      }
    end

    # Whether the ledger being looked at is narrowed at all. `q` counts: it
    # narrows the ledger just as much as the filter menu does, even though it
    # renders outside it. A param that resolved to nothing doesn't count: it
    # narrowed nothing.
    def ledger_filtered?
      ledger_filter_predicates.any?
    end

    # The filters, as params, for handing to another request — an export link,
    # most of all, which has to reproduce this exact ledger.
    def ledger_filter_params
      params.permit(:q, *FILTER_PARAMS).to_h.compact_blank.symbolize_keys
    end

  end

end
