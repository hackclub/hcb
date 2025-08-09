# frozen_string_literal: true

module Api
  module V4
    class InvoicesController < ApplicationController
      def index
        @event = Event.find_by_public_id(params[:event_id]) || Event.friendly.find(params[:event_id])
        @invoices = authorize(@event.invoices.order(created_at: :desc))
      end

      def show
        @invoice = authorize Invoice.find_by_public_id(params[:id])
      end

      def create
        event = authorize Event.find_by_public_id(params[:organization_id]) || Event.friendly.find(params[:organization_id])
        authorize event, :create?, policy_class: InvoicePolicy

        sponsor_attrs = filtered_params[:sponsor_attributes]

        due_date = filtered_params["due_date"].to_datetime

        # we use public ids most places in the api so we need to convert this to a model to get the regular id
        # if this record doesnt exist it will fall back to the sponsor attributes provided and generate a sponsor
        # if the record does exist it will be updated by the invoice service to the new sponsor attributes provided here
        sponsor = authorize Sponsor.find_by_public_id(sponsor_attrs[:id])

        @invoice = ::InvoiceService::Create.new(
          event_id: event.id,
          due_date:,
          item_description: filtered_params[:item_description],
          item_amount: filtered_params[:item_amount],
          current_user:,
          sponsor_id: sponsor.id,
          sponsor_name: sponsor_attributes[:name],
          sponsor_email: sponsor_attributes[:contact_email],
          sponsor_address_line1: sponsor_attributes[:address_line1],
          sponsor_address_line2: sponsor_attributes[:address_line2],
          sponsor_address_city: sponsor_attributes[:address_city],
          sponsor_address_state: sponsor_attributes[:address_state],
          sponsor_address_postal_code: sponsor_attributes[:address_postal_code],
          sponsor_address_country: sponsor_attributes[:address_country]
        ).run

        render :show
      rescue Pundit::NotAuthorizedError
        raise
      rescue => e
        Rails.error.report(e)

        return render json: { error: e.message }, status: :internal_server_error
      end

      private

      def filtered_params
        params.require(:invoice).permit(
          :due_date,
          :item_description,
          :item_amount,
          :sponsor_id,
          sponsor_attributes: policy(Sponsor).permitted_attributes
        )
      end

    end

  end
end
