# frozen_string_literal: true

module Api
  module V4
    class TransactionsController < ApplicationController
      skip_after_action :verify_authorized, only: [:missing_receipt]

      def show
        @hcb_code = authorize HcbCode.find_by_public_id!(params[:id])

        if params[:event_id]
          @event = Event.find_by_public_id(params[:event_id]) || Event.friendly.find(params[:event_id])
          raise ActiveRecord::RecordNotFound if !@hcb_code.events.include?(@event)
        else
          @event = @hcb_code.events.find { |e| e.users.include?(current_user) } || @hcb_code.events.first
        end
      end

      def missing_receipt
        user_hcb_code_ids = current_user.stripe_cards.flat_map { |card| card.hcb_codes.pluck(:id) }
        user_hcb_codes = HcbCode.where(id: user_hcb_code_ids)

        hcb_codes_missing_ids = user_hcb_codes.missing_receipt.receipt_required.pluck(:id)
        @hcb_codes = HcbCode.where(id: hcb_codes_missing_ids).order(created_at: :desc)

        @total_count = @hcb_codes.size
        @has_more = false # TODO: implement pagination
      end

      def update
        @event = Event.find_by_public_id(params[:event_id]) || Event.friendly.find(params[:event_id])
        @hcb_code = authorize HcbCode.find_by_public_id(params[:id])

        if params.key? :memo
          @hcb_code.canonical_transactions.each { |ct| ct.update!(custom_memo: params[:memo]) }
          @hcb_code.canonical_pending_transactions.each { |cpt| cpt.update!(custom_memo: params[:memo]) }
        end

        render "show"
      end

      def memo_suggestions
        @event = Event.find_by_public_id(params[:event_id]) || Event.friendly.find(params[:event_id])
        @hcb_code = authorize HcbCode.find_by_public_id(params[:id]), :update?

        @suggested_memos = ::HcbCodeService::SuggestedMemos.new(hcb_code: @hcb_code, event: @event).run.first(4)
      end

    end
  end
end
