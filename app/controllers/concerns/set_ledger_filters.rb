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
      @start_date = params[:start].presence
      @end_date = params[:end].presence
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
      # Resolved as two plain id lookups unioned in Ruby, rather than
      # `User.where(id: ...).or(User.where(id: ...))` with each side a
      # subquery: Postgres was choosing to evaluate both subqueries as a
      # "hashed SubPlan" filter under a sequential scan of the entire `users`
      # table instead of an indexed id lookup, on ledgers with many items.
      author_ids = Ledger::Item.where(id: Ledger::Mapping.where(ledger: @ledgers).select(:ledger_item_id)).distinct.pluck(:author_id)
      user_ids = (author_ids.compact + @event.users.pluck(:id)).uniq
      @users = User.where(id: user_ids).with_attached_profile_picture.order(Arel.sql("CONCAT(preferred_name, full_name) ASC"))

      # Found from @users (not @event.users): a non-organizer who has authored
      # a transaction is still a valid author to filter by. See #14667.
      @user = @users.friendly.find(params[:user], allow_nil: true) if params[:user]

      if @merchant
        merchant = @event.merchants.find { |merchant| merchant[:id] == @merchant }

        @merchant_name = merchant.present? ? merchant[:name] : "Merchant #{@merchant}"
      end
    end

    def ledger_query
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

      query << { datetime: { "$gte": @start_date.to_date } } if @start_date.present?
      # Whole-day inclusive end bound, matching the old transactions page
      query << { datetime: { "$lt": @end_date.to_date.next_day } } if @end_date.present?

      query << { author: { "$eq": @user&.slug || params[:user] } } if params[:user].present?

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

      # Amount trumps status: an item that moved any non-zero amount should
      # always render (e.g. a declined/failed transaction that still posted a
      # partial charge), regardless of its status. Only zero-amount items are
      # subject to the status allowlist.
      query << {
        "$or": [
          { amount_cents: { "$ne": 0 } },
          { status: { "$in": ["settled", "pending", "reversed"] } }
        ]
      }
      Ledger::Query.new({ "$and": query })
    end

  end

end
