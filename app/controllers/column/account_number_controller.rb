# frozen_string_literal: true

module Column
  class AccountNumberController < ApplicationController
    include SetEvent
    before_action :set_event

    def create
      if @event.column_account_number.nil?
        column_account_number = authorize @event.build_column_account_number
        column_account_number.save!
        @animated = true

        # The eye on the account number page and in the account numbers modal posts
        # here from inside a turbo frame. That frame gets the new number rendered
        # into it, so the page it's on stays put.
        case turbo_frame_request_id
        when "account_number_details"
          return render partial: "events/account_number_details", locals: { animated: true }
        when "account_number_modal"
          return render partial: "events/account_number_modal", locals: { animated: true }
        end

        if Flipper.enabled?(:new_ledger_everywhere_2026_07_13, current_user)
          @ledger = @event.ledger
          @ledger_items = @ledger.items.none.page(1)
        end

        render "events/account_number", status: :unprocessable_content
      else
        skip_authorization
        redirect_to account_number_event_path(@event)
      end

    rescue Faraday::Error => e
      Rails.error.report(e)
      redirect_to account_number_event_path(@event), flash: { error: "Something went wrong: #{e.response_body["message"]}" }

    end

    def update
      authorize @event.column_account_number
      @event.column_account_number.update!(params.require(:column_account_number).permit(:deposit_only))
      redirect_back_or_to account_number_event_path(@event)
    end

  end
end
