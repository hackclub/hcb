# frozen_string_literal: true

module HcbCodeService
  class SuggestedMemos
    # Users on HCB generally like to rename transactions (set a custom_memo)
    # to provide a better appearance on their ledger. HQ generally prefixes
    # memos with emojis. The goal of this service to analyze similar
    # transactions and provide memo suggestions.

    def initialize(hcb_code:, event:, confidence: 0.4)
      @hcb_code = HcbCode.find(hcb_code.id) # need to reload object due to "manual" preload
      @event = event
      @confidence = confidence
    end

    def run
      return [] unless @event

      @hcb_code.suggested_memos + ranked_similar_transactions.pluck(:transaction).pluck(:custom_memo).uniq
    end

    def ranked_similar_transactions
      hcb_amount = @hcb_code.amount_cents
      hcb_type = @hcb_code.hcb_i1
      hcb_amount_sign = @hcb_code.amount_cents.positive?
      hcb_linked_obj = @hcb_code.try(@hcb_code.type) if @hcb_code.type
      if @hcb_code.type == :card_charge
        hcb_linked_obj = @hcb_code.raw_stripe_transaction
      end

      # Apply additional ranking on top of PG's full text search. This is where
      # can can apply additional context outside of the transaction memo.
      similar_transactions.map do |t|
        {
          transaction: t,
          ranking: rank_transaction(
            t,
            hcb_amount:,
            hcb_type:,
            hcb_amount_sign:,
            hcb_linked_obj:
          )
        }
      end.select { |tr| tr[:ranking] >= @confidence }.sort_by { |tr| tr[:ranking] }.reverse!
    end

    def rank_transaction(transaction, hcb_amount:, hcb_type:, hcb_amount_sign:, hcb_linked_obj:)
      pg_rank = transaction.pg_search_rank
      # For each of the following factors that a transaction meets, it is
      # more likely to be "promoted" to the top of the list.
      # The weights given to each other are with respect to other factors.
      t_linked_obj = transaction.linked_object || transaction.raw_stripe_transaction

      compare_linked = proc do |model, comps|
        next 0 unless hcb_linked_obj.instance_of?(model)
        next 0 unless hcb_linked_obj.instance_of?(t_linked_obj.class)

        points = possible_points = 0
        comps.each do |comp|
          possible_points += comp[:points]
          attr = [comp[:attr]].flatten

          get_attr = proc do |obj|
            attr.reduce(obj) { |o, curr_attr| o.try(curr_attr) || o[curr_attr] }
          rescue
            nil
          end

          hcb_attr = get_attr.call(hcb_linked_obj)
          t_attr = get_attr.call(t_linked_obj)
          ap [comp[:attr], hcb_attr, t_attr] if Rails.env.development?

          points += comp[:points] if hcb_attr == t_attr
        end

        points / possible_points
      end

      [
        { weight: 0.2, value: transaction.local_hcb_code.hcb_i1 == hcb_type }, # same tx type
        { weight: 0.5, value: transaction.amount_cents.positive? == hcb_amount_sign }, # same sign
        { weight: 0.1, value: transaction.amount_cents == hcb_amount }, # same amount
        { weight: 0.3, value: transaction.date.to_time.to_f / Time.now.to_i }, # most recent
        { weight: 0.05, value: (/\p{Emoji}/ =~ transaction.custom_memo.first).present? }, # bias emoji
        { weight: 0.3, value: compare_linked.call(
          Invoice,
          [
            {
              attr: [:sponsor, :id],
              points: 1
            },
            {
              attr: :payment_method_card_last4,
              points: 2
            },
            {
              attr: :payment_method_ach_credit_transfer_account_number,
              points: 2
            }
          ]
        )
        },
        { weight: 0.3, value: compare_linked.call(
          Donation,
          [
            {
              attr: :name,
              points: 1
            },
            {
              attr: :email,
              points: 2
            },
            {
              attr: :payment_method_card_last4,
              points: 3
            }
          ]
        )
        },
        { weight: 0.3, value: compare_linked.call(
          AchTransfer,
          [
            {
              attr: :account_number,
              points: 2
            },
            {
              attr: :payment_for,
              points: 2
            },
            {
              attr: :recipient_name,
              points: 1
            },
            {
              attr: :creator_id,
              points: 0.2
            }
          ]
        )
        },
        { weight: 0.3, value: compare_linked.call(
          Disbursement,
          [
            {
              attr: :source_event,
              points: 1
            },
            {
              attr: :destination_event,
              points: 1
            },
            {
              attr: :name,
              points: 3
            },
            {
              attr: :requested_by_id,
              points: 0.2
            }
          ]
        )
        },
        { weight: 0.3, value: compare_linked.call(
          RawStripeTransaction,
          [
            {
              attr: [:stripe_transaction, "cardholder"],
              points: 0.5
            },
            {
              attr: [:stripe_transaction, "merchant_data", "name"],
              points: 2
            },
            {
              attr: [:stripe_transaction, "merchant_data", "category_code"],
              points: 1
            },
            {
              attr: [:stripe_transaction, "merchant_data", "postal_code"],
              points: 0.2
            },
          ]
        )
        }
      ].reduce(0) do |sum, factor|
        val = factor[:value]
        if val.in? [true, false]
          val = val ? pg_rank * 1.3 : pg_rank
        end

        sum + (val * factor[:weight])
      end
    end

    def similar_transactions
      similar_canonical_transactions + similar_canonical_pending_transactions
    end

    def similar_canonical_transactions
      find_similar_from :canonical_transactions
    end

    def similar_canonical_pending_transactions
      find_similar_from :canonical_pending_transactions
    end

    private

    def find_similar_from(type)
      collection = @event.public_send(type)
      joined_memos = existing_memos.uniq.join " "
      against_cols = {
        memo: "B", custom_memo: "A", hcb_code: "C" # Columns are weighted
      }
      if type == :canonical_transactions
        against_cols.merge!({ friendly_memo: "B" })
      end

      # The similar transaction must not be from this hcb code, and it must have a custom memo
      collection.where.not(custom_memo: nil)
                .where.not(hcb_code: @hcb_code.hcb_code)
                .where.not("custom_memo = memo")
                .pg_text_search(joined_memos,
                                {
                                  against: against_cols,
                                  using: {
                                    tsearch: { prefix: true, dictionary: "english", any_word: true }
                                  }
                                })
                .with_pg_search_rank
                .limit(10)
    end

    def existing_memos
      (existing_raw_memos + existing_custom_memos).uniq
    end

    def existing_raw_memos
      (
        @hcb_code.canonical_transactions.flat_map do |ct|
          [ct.memo, ct.friendly_memo]
        end +
          @hcb_code.canonical_pending_transactions.map(&:memo)
      ).compact
    end

    def existing_custom_memos
      (@hcb_code.canonical_transactions + @hcb_code.canonical_pending_transactions)
        .map(&:custom_memo).compact
    end

  end
end
