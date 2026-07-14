# frozen_string_literal: true

# Adds a `set_ledger_filters` method to a controller. Requires `@event` to be
# set. Set `@include_card_grant_ledgers` beforehand to also include the
# event's card grant ledgers (e.g. for the grant overview) when determining
# filterable users.
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

      ledgers = if @include_card_grant_ledgers
                  Ledger.where(event: @event).or(Ledger.where(card_grant: @event.card_grants))
                else
                  @event.ledger
                end
      author_ids = Ledger::Item.where(id: Ledger::Mapping.where(ledger: ledgers).select(:ledger_item_id)).select(:author_id)
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

  end

end
