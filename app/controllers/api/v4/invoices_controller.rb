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
        skip_authorization
        @invoice = Invoice.find_by_public_id!(params[:id])
        authorize @invoice
      rescue => e
        return render json: { error: e.message }, status: :bad_request
      end

      def create
        authorize @event, :create?

        due_date = invoice_params["due_date"].to_datetime

        sponsor = Sponsor.find_by_public_id(params[:sponsor_id])
        authorize sponsor

        @invoice = ::InvoiceService::Create.new(
          event_id: @event.id,
          due_date:,
          item_description: invoice_params[:item_description],
          item_amount: invoice_params[:item_amount],
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

        render :show, status: :created, location: api_v4_invoice_path(@invoice)
      end

      private

      def invoice_params
        params.require(:invoice).permit(
          :due_date,
          :item_description,
          :item_amount
        )
      end

    end
  end
end
