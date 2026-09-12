# frozen_string_literal: true

module Api
  module V5
    class TransactionsController < ApplicationController
      # v5 transactions are `Ledger::Item`s, not `HcbCode`s. That is the
      # breaking change v5 exists for, and it also removes the last index in
      # this API that could not use `policy_scope`: the HcbCode-era index was a
      # projection of the settled and pending engines, with no relation to
      # filter, so it had to authorize the organization instead. A ledger item
      # is an ordinary record, so the index is a scope like every other.
      def index
        @items = policy_scope(Ledger::Item)
                 .preload(:tags, :primary_ledger, :linked_object, hcb_code: :event)
                 .order(datetime: :desc)

        if params[:organization_id].present?
          @items = @items.where(id: ledger_item_ids_for_organization(params[:organization_id]))
        end

        @items = paginate_cursor(@items.to_a, &:public_id)
      end

      require_oauth2_scope "ledgers:read", :index

      def show
        @item = authorize Ledger::Item.find_by_public_id!(params[:id]), :show_any_attribute?
      end

      require_oauth2_scope "ledgers:read", :show

      def update
        @item = authorize Ledger::Item.find_by_public_id!(params[:id]), :rename?

        ActiveRecord::Base.transaction do
          @item.update_custom_memo!(params[:memo]) if params.key?(:memo)

          if params.key?(:tag_ids)
            tags = Array(params[:tag_ids]).map { |id| Tag.find_by_public_id!(id) }

            tags.each do |tag|
              authorize tag, :toggle_tag?
              # A tag from another organization would otherwise be attachable by
              # anyone who can tag anything.
              raise Pundit::NotAuthorizedError unless @item.hcb_code&.events&.include?(tag.event)
            end

            @item.hcb_code.tags = tags
            @item.hcb_code.save!
            @item.refresh!
          end
        end

        render :show
      end

      require_oauth2_scope "transactions:write", :update

      def mark_no_receipt
        item = authorize Ledger::Item.find_by_public_id!(params[:id]), :mark_no_or_lost?, policy_class: ReceiptablePolicy
        item.no_or_lost_receipt!

        render json: { message: "Transaction marked as no/lost receipt" }, status: :ok
      end

      require_oauth2_scope "receipts:write", :mark_no_receipt

      private

      # Narrows the scope to one organization without loading it. Filtering can
      # only ever narrow what `policy_scope` already allows, so an organization
      # the viewer cannot read yields an empty page rather than a 403 that would
      # confirm it exists.
      def ledger_item_ids_for_organization(param)
        events = Event.where_public_id(param).or(Event.where(slug: param))
        ledgers = ::Ledger.where(event: events).or(::Ledger.where(card_grant: CardGrant.where(event: events)))

        ::Ledger::Mapping.where(ledger: ledgers).select(:ledger_item_id)
      end

    end
  end
end
