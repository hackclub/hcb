# frozen_string_literal: true

module Api
  module V4
    class InvoicesController < ApplicationController
      include SetEvent

      before_action :set_api_event, only: [:index, :create]

      def index
        @invoices = authorize(@event.invoices.order(created_at: :desc))
      end

      def show
        @invoice = Invoice.find_by_public_id!(params[:id])
        authorize @invoice
      rescue => e
        return render json: { error: e.message }, status: :bad_request
      end

      def create
        authorize @event, :create?

        filtered_params = params.require(:invoice).permit(
          :due_date,
          :item_description,
          :item_amount
        )

        due_date = filtered_params["due_date"].to_datetime

        sponsor = authorize Sponsor.find_by_public_id(params[:sponsor_id])

        @invoice = ::InvoiceService::Create.new(
          event_id: event.id,
          due_date:,
          item_description: filtered_params[:item_description],
          item_amount: filtered_params[:item_amount],
          current_user:,
          sponsor_id: sponsor.id,
          sponsor_name: sponsor.name,
          sponsor_email: sponsor.contact_email,
          sponsor_address_line1: sponsor.address_line1,
          sponsor_address_line2: sponsor.address_line2,
          sponsor_address_city: sponsor.address_city,
          sponsor_address_state: sponsor.address_state,
          sponsor_address_postal_code: sponsor.address_postal_code,
          sponsor_address_country: sponsor.address_country
        ).run

        render :show
      rescue Pundit::NotAuthorizedError
        raise
      rescue => e
        Rails.error.report(e)

        return render json: { error: e.message }, status: :internal_server_error
      end

    end
  end
end
