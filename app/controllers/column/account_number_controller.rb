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
        render "events/account_number", status: :unprocessable_entity
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
