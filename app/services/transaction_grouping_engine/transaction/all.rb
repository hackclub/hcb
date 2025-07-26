# frozen_string_literal: true

module TransactionGroupingEngine
  module Transaction
    class All
      def initialize(event_id:, search: nil, tag_id: nil, expenses: false, revenue: false, minimum_amount: nil, maximum_amount: nil, start_date: nil, end_date: nil, user: nil, missing_receipts: false)
        @event_id = event_id
        @search = ActiveRecord::Base.sanitize_sql_like(search || "")
        @tag_id = tag_id&.to_i
        @expenses = expenses
        @revenue = revenue
        @minimum_amount = minimum_amount
        @maximum_amount = maximum_amount
        @start_date = start_date&.to_datetime
        @end_date = end_date&.to_datetime
        @user = user
        @missing_receipts = missing_receipts
      end

      def run
        all
      end

      def running_balance_by_date
        query = <<~SQL
          WITH rbt AS (#{running_balance_sql})
          SELECT GREATEST(0, AVG(running_balance)) as running_balance, date FROM rbt
          GROUP BY date
          ORDER BY date
        SQL

        ActiveRecord::Base.connection.execute(query).map { |entry| [entry["date"].to_date, entry["running_balance"]] }.to_h
      end

      def running_balance_sql
        query = <<~SQL
          SELECT sum(amount_cents) over (order by date asc rows between unbounded preceding and current row) as running_balance, *
          FROM (
            #{canonical_transactions_grouped_sql}
          ) canonical_transactions_grouped
          ORDER BY date
        SQL
      end

      def all
        canonical_transactions_grouped.map do |ctg|
          build(ctg)
        end
      end

      def sum
        all.sum { |t| t.amount_cents }
      end

      private

      def build(ctg)
        attrs = {
          hcb_code: ctg["hcb_code"],
          date: ctg["date"],
          amount_cents: ctg["amount_cents"],
          raw_canonical_transaction_ids: ctg["canonical_transaction_ids"],
          raw_canonical_pending_transaction_ids: ctg["canonical_pending_transaction_ids"],
          event:,
          subledger: nil,
        }
        CanonicalTransactionGrouped.new(attrs)
      end

      def event
        @event ||= Event.find(@event_id)
      end

      def canonical_event_mappings
        @canonical_event_mappings ||= CanonicalEventMapping.where(event_id: event.id)
      end

      def canonical_transactions
        @canonical_transactions ||= CanonicalTransaction.includes(:receipts).where(id: canonical_event_mappings.pluck(:canonical_transaction_id)).order("date desc, id desc")
      end

      def canonical_transaction_ids
        @canonical_transaction_ids ||= canonical_event_mappings.pluck(:canonical_transaction_id)
      end

      def search_modifier_for(type)
        return "" unless @search.present?

        type = type.to_s

        if type == "ct"
          return ActiveRecord::Base.sanitize_sql_array(["and (ct.memo ilike :query or ct.friendly_memo ilike :query or ct.custom_memo ilike :query)", { query: "%#{@search}%" }])
        end

        ActiveRecord::Base.sanitize_sql_array(["and (#{type}.memo ilike :query or #{type}.custom_memo ilike :query)", { query: "%#{@search}%" }])
      end

      def user_modifier
        return "" unless @user&.stripe_cardholder&.stripe_id.present?

        ActiveRecord::Base.sanitize_sql_array(["and raw_stripe_transactions.stripe_transaction->>'cardholder' = ?", @user.stripe_cardholder.stripe_id])
      end

      def user_joins_for(type)
        return "" unless @user.present?

        type = type.to_s

        return "left join raw_stripe_transactions on raw_stripe_transactions.id = transaction_source_id AND transaction_source_type = 'RawStripeTransaction'" if type == "ct"

        "left join raw_stripe_transactions on raw_stripe_transactions.id = raw_pending_stripe_transaction_id"
      end

      def modifiers
        joins = []
        conditions = []
        query_params = {}

        if @tag_id
          joins << <<~SQL
            left join hcb_codes on hcb_codes.hcb_code = q1.hcb_code
            left join hcb_codes_tags on hcb_codes_tags.hcb_code_id = hcb_codes.id
          SQL
          conditions << "hcb_codes_tags.tag_id = :tag_id"
          query_params.merge!({ tag_id: @tag_id })
        end

        if !@tag_id && @missing_receipts
          joins << <<~SQL
            left join hcb_codes on hcb_codes.hcb_code = q1.hcb_code
          SQL
        end

        if @missing_receipts
          joins << <<~SQL
            left join receipts on receipts.receiptable_id = hcb_codes.id AND receipts.receiptable_type = 'HcbCode'
          SQL
          conditions << "receipts.id IS NULL AND hcb_codes.marked_no_or_lost_receipt_at is NULL AND q1.amount_cents <= 0"
        end

        conditions << "q1.amount_cents < 0" if @expenses
        conditions << "q1.amount_cents >= 0" if @revenue

        if @minimum_amount
          conditions << "ABS(q1.amount_cents) >= :min_cents"
          query_params.merge!({ min_cents: @minimum_amount.cents })
        end

        if @maximum_amount
          conditions << "ABS(q1.amount_cents) <= :max_cents"
          query_params.merge!({ max_cents: @maximum_amount.cents })
        end

        if @start_date
          conditions << "#{date_select} >= cast(:start_date as date)"
          query_params.merge!({ start_date: @start_date })
        end

        if @end_date
          conditions << "#{date_select} <= cast(:end_date as date)"
          query_params.merge!({ end_date: @end_date })
        end

        return if conditions.none?

        sanitized_conditions = ActiveRecord::Base.sanitize_sql_array([conditions.join(" and "), query_params])
        "#{joins.join(" ")} where #{sanitized_conditions}"
      end

      def date_select
        <<~SQL
          (
            select date
            from (
              select date
              from (
                select date from canonical_pending_transactions where id = any(q1.pt_ids) order by date asc, id asc limit 1
              ) pt_raw
              union
              select date
              from (
                select date from canonical_transactions where id = any(q1.ct_ids) order by date asc, id asc limit 1
              ) ct_raw
            ) raw
            order by date asc limit 1
          )
        SQL
      end

      def canonical_transactions_grouped_sql
        pt_group_sql = <<~SQL
          select
            array_agg(pt.id) as pt_ids
            ,array[]::bigint[] as ct_ids
            ,coalesce(pt.hcb_code, cast(pt.id as text)) as hcb_code
            ,sum(pt.amount_cents) as amount_cents
            ,sum(pt.amount_cents / 100.0)::float as amount
          from
            canonical_pending_transactions pt
          #{user_joins_for :pt}
          where
            fronted = true -- only included fronted pending transactions
            and
            pt.id in (
              select
                cpem.canonical_pending_transaction_id
              from
                canonical_pending_event_mappings cpem
              where
                cpem.event_id = :event_id
                and cpem.subledger_id is null
              except ( -- hide pending transactions that have either settled or been declined.
                select
                  cpsm.canonical_pending_transaction_id
                from
                  canonical_pending_settled_mappings cpsm
                union
                select
                  cpdm.canonical_pending_transaction_id
                from
                  canonical_pending_declined_mappings cpdm
              )
            )
            and
            not exists ( -- hide pt if there are ct in its hcb code (handles edge case of unsettled PT)
              select *
              from canonical_transactions ct
              inner join canonical_event_mappings cem on cem.canonical_transaction_id = ct.id
              where ct.hcb_code = pt.hcb_code and cem.event_id = :event_id
            )
            #{search_modifier_for :pt}
            #{user_modifier}
          group by
            coalesce(pt.hcb_code, cast(pt.id as text)) -- handle edge case when hcb_code is null
        SQL

        ct_group_sql = <<~SQL
          select
            array[]::bigint[] as pt_ids
            ,array_agg(ct.id) as ct_ids
            ,coalesce(ct.hcb_code, cast(ct.id as text)) as hcb_code
            ,sum(ct.amount_cents) as amount_cents
            ,sum(ct.amount_cents / 100.0)::float as amount
          from
            canonical_transactions ct
          #{user_joins_for :ct}
          where
            ct.id in (
              select
                cem.canonical_transaction_id
              from
                canonical_event_mappings cem
              where
                cem.event_id = :event_id
                and cem.subledger_id is null
            )
            #{search_modifier_for :ct}
            #{user_modifier}
          group by
            coalesce(ct.hcb_code, cast(ct.id as text)) -- handle edge case when hcb_code is null
        SQL

        canonical_pending_transactions_select = <<~SQL
          (
            select json_agg(raw)
            from (
              select *, (amount_cents / 100.0) as amount from canonical_pending_transactions where id = any(q1.pt_ids) order by date desc, id desc
            ) raw
          )
        SQL

        canonical_pending_transaction_ids_select = <<~SQL
          (
            select array_to_json(array_agg(id))
            from (
              select id from canonical_pending_transactions where id = any(q1.pt_ids) order by date desc, id desc
            ) raw
          )
        SQL

        canonical_transactions_select = <<~SQL
          (
            select json_agg(raw)
            from (
              select *, (amount_cents / 100.0) as amount from canonical_transactions where id = any(q1.ct_ids) order by date desc, id desc
            ) raw
          )
        SQL

        canonical_transaction_ids_select = <<~SQL
          (
            select array_to_json(array_agg(id))
            from (
              select id from canonical_transactions where id = any(q1.ct_ids) order by date desc, id desc
            ) raw
          )
        SQL

        q = <<~SQL
          select
            q1.ct_ids -- ct_ids and pt_ids in this query are mutually exclusive
            ,q1.pt_ids
            ,q1.hcb_code
            ,q1.amount_cents
            ,q1.amount::float
            ,(#{date_select}) as date
            ,(#{canonical_pending_transaction_ids_select}) as canonical_pending_transaction_ids
            ,(#{canonical_pending_transactions_select}) as canonical_pending_transactions
            ,(#{canonical_transaction_ids_select}) as canonical_transaction_ids
            ,(#{canonical_transactions_select}) as canonical_transactions
          from (
            #{event.can_front_balance? ? "#{pt_group_sql}\nunion" : ''}
            #{ct_group_sql}
          ) q1
          #{modifiers}
          order by date desc, pt_ids[1] desc, ct_ids[1] desc
        SQL

        ActiveRecord::Base.sanitize_sql_array([q, { event_id: @event_id }])
      end

      def canonical_transactions_grouped
        ActiveRecord::Base.connection.execute(canonical_transactions_grouped_sql)
      end

    end
  end
end
