# frozen_string_literal: true

module SetLedgerFilters
  extend ActiveSupport::Concern

  included do
    private

    def set_ledger_filters
      # The search query name was historically `search`. It has since been renamed
      # to `q`. This following line retains backwards compatibility.
      params[:q] ||= params[:search]

      if params[:tag]
        @tag = Tag.find_by(event_id: @event.id, label: params[:tag])
      end

      @user = @event.users.friendly.find(params[:user], allow_nil: true) if params[:user]

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
      author_ids = Ledger::Item.where(id: Ledger::Mapping.where(ledger: @ledgers).select(:ledger_item_id)).select(:author_id)
      @users = User.where(id: author_ids).or(User.where(id: @event.users.select(:id))).with_attached_profile_picture.order(Arel.sql("CONCAT(preferred_name, full_name) ASC"))

      if @merchant
        merchant = @event.merchants.find { |merchant| merchant[:id] == @merchant }

        @merchant_name = merchant.present? ? merchant[:name] : "Merchant #{@merchant}"
      end

      @ledger_filters_disabled = !signed_in?
      has_filters = @tag || @user || @type || @start_date || @end_date || @minimum_amount || @maximum_amount || @missing_receipts || @merchant || @direction || @category
      if @ledger_filters_disabled && has_filters
        render plain: "Invalid parameters. Please try again", status: :bad_request
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

      query << { author: { "$eq": @user.slug } } if @user.present?

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

      # TODO: add filtering for merchant and category

      query << { status: { "$in": [nil, "settled", "pending", "reversed"] } } # TODO: add not null validation and remove nil status from here
      Ledger::Query.new({ "$and": query })
    end

  end

end
