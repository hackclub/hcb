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
        merchant = ledger_merchants(@ledgers).find { |merchant| merchant[:id] == @merchant }

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

    # Distinct merchants for the given ledgers' CardCharge items, with a
    # transaction count per merchant. Scoped to Ledger::Item so this only
    # reflects card charges that are actually mapped onto these ledgers.
    #
    # Merchant data lives in a JSONB blob on the underlying raw Stripe
    # transaction; pulling the whole blob per charge (e.g. via
    # `card_charge.merchant_data`, which loads full `RawStripeTransaction`/
    # `RawPendingStripeTransaction` records) is the expensive part at this
    # volume, not the merchant lookup itself. Extracting just the
    # `merchant_data` key with the `->` operator keeps the query and the
    # amount of data pulled back small.
    def ledger_merchants(ledgers)
      card_charge_ids = Ledger::Item.where(
        linked_object_type: "CardCharge",
        id: Ledger::Mapping.where(ledger: ledgers).select(:ledger_item_id)
      ).pluck(:linked_object_id)
      return [] if card_charge_ids.empty?

      merchant_data_by_charge_id = {}

      # A card charge's `merchant_data` prefers its latest settled
      # RawStripeTransaction, falling back to its RawPendingStripeTransaction
      # (mirrors CardCharge#merchant_data's `raw_stripe_transactions.last ||
      # raw_pending_stripe_transaction`).
      last_settled_transaction_id_by_charge_id = CardChargeRawStripeTransaction
                                                 .where(card_charge_id: card_charge_ids)
                                                 .group(:card_charge_id)
                                                 .maximum(:raw_stripe_transaction_id)

      if last_settled_transaction_id_by_charge_id.present?
        charge_id_by_transaction_id = last_settled_transaction_id_by_charge_id.invert
        RawStripeTransaction.where(id: last_settled_transaction_id_by_charge_id.values)
                            .pluck(:id, Arel.sql("stripe_transaction -> 'merchant_data'"))
                            .each do |transaction_id, merchant_data|
          next if merchant_data.blank?

          merchant_data_by_charge_id[charge_id_by_transaction_id[transaction_id]] = merchant_data
        end
      end

      pending_only_charge_ids = card_charge_ids - merchant_data_by_charge_id.keys
      if pending_only_charge_ids.present?
        CardCharge.where(id: pending_only_charge_ids)
                  .joins(:raw_pending_stripe_transaction)
                  .pluck(:id, Arel.sql("raw_pending_stripe_transactions.stripe_transaction -> 'merchant_data'"))
                  .each do |charge_id, merchant_data|
          next if merchant_data.blank?

          merchant_data_by_charge_id[charge_id] = merchant_data
        end
      end

      merchant_data_by_charge_id.values.group_by { |merchant_data| merchant_data["network_id"] }.map do |network_id, group|
        yellow_pages_merchant = YellowPages::Merchant.lookup(network_id:)
        { id: network_id, name: yellow_pages_merchant.name || group.first["name"].titleize, count: group.size }
      end
    end

  end

end
