# frozen_string_literal: true

module TransactionGroupingEngine
  module Transaction
    class All
      def initialize(event_id:)
        @event_id = event_id
      end

      def run
        Kaminari.paginate_array(all)
      end

      def all
        @all ||= canonical_transactions_grouped.map do |ctg|
          build(ctg)
        end
      end

      private

      def build(ctg)
        attrs = {
          hcb_code: ctg["hcb_code"],
          date: ctg["date"],
          amount_cents: ctg["amount_cents"],
          raw_canonical_transaction_ids: ctg["canonical_transaction_ids"]
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

      def canonical_transactions_grouped(page: 1)
        group_sql = <<~SQL
          select 
            array_agg(ct.id) as ids
            ,coalesce(ct.hcb_code, cast(ct.id as text)) as hcb_code
            ,sum(ct.amount_cents) as amount_cents
            ,sum(ct.amount_cents / 100.0)::float as amount
          from
            canonical_transactions ct
          where
            ct.id in (
              select
                cem.canonical_transaction_id
              from
                canonical_event_mappings cem
              where
                cem.event_id = #{event.id}
            )
          group by
            coalesce(ct.hcb_code, cast(ct.id as text)) -- handle edge case when hcb_code is null
        SQL
        
        date_select = <<~SQL
          ( 
            select date
            from (
              select date from canonical_transactions where id = any(q1.ids) order by date desc, id desc limit 1
            ) raw
          )
        SQL

        canonical_transactions_select = <<~SQL
          ( 
            select json_agg(raw) 
            from (
              select *, (amount_cents / 100.0) as amount from canonical_transactions where id = any(q1.ids) order by date desc, id desc
            ) raw
          )
        SQL

        canonical_transaction_ids_select = <<~SQL
          ( 
            select array_to_json(array_agg(id))
            from (
              select id from canonical_transactions where id = any(q1.ids) order by date desc, id desc
            ) raw
          )
        SQL

        q = <<~SQL
          select
            q1.hcb_code
            ,q1.amount_cents
            ,q1.amount::float
            ,(#{date_select}) as date
            ,(#{canonical_transaction_ids_select}) as canonical_transaction_ids
            ,(#{canonical_transactions_select}) as canonical_transactions
          from (
            #{group_sql}
          ) q1
        SQL

        ActiveRecord::Base.connection.execute(q)
      end
    end
  end
end
