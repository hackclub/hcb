# frozen_string_literal: true

module Api
  module V4
    class InvoicesController < ApplicationController
      def index
        if params[:event_id].present?
          @event = authorize(Event.find_by_public_id(params[:organization_id]) || Event.friendly.find(params[:organization_id]), :is_public)
          @invoices = @event.invoices.includes(:user, :event).order(created_at: :desc)
        end
      end

      def show
        @invoice = authorize Invoice.friendly.find(params[:id])
      end

      def create
        event = authorize(Event.find(params[:organization_id]))
        authorize event, policy_class: InvoicePolicy

        filtered_params = params.require(:invoice).permit(
          :due_date,
          :item_description,
          :item_amount,
          :sponsor_id,
          sponsor_attributes: policy(Sponsor).permitted_attributes
        )
    
        sponsor_attrs = filtered_params[:sponsor_attributes]
    
        due_date = Date.civil(filtered_params["due_date(1i)"].to_i,
                              filtered_params["due_date(2i)"].to_i,
                              filtered_params["due_date(3i)"].to_i)
    
        @invoice = ::InvoiceService::Create.new(
          event_id: event.id,
          due_date:,
          item_description: filtered_params[:item_description],
          item_amount: filtered_params[:item_amount],
          current_user:,
    
          sponsor_id: sponsor_attrs[:id],
          sponsor_name: sponsor_attrs[:name],
          sponsor_email: sponsor_attrs[:contact_email],
          sponsor_address_line1: sponsor_attrs[:address_line1],
          sponsor_address_line2: sponsor_attrs[:address_line2],
          sponsor_address_city: sponsor_attrs[:address_city],
          sponsor_address_state: sponsor_attrs[:address_state],
          sponsor_address_postal_code: sponsor_attrs[:address_postal_code],
          sponsor_address_country: sponsor_attrs[:address_country]
        ).run
    
        unless OrganizerPosition.find_by(user: @invoice.creator, event: @event)&.manager?
          InvoiceMailer.with(invoice: @invoice).notify_organizers_sent.deliver_later
        end
    
        render :show
      rescue Pundit::NotAuthorizedError
        raise
      rescue => e
        Rails.error.report(e)
    
        @sponsor = Sponsor.new(event: @event)
        @invoice = Invoice.new(sponsor: @sponsor)

        return render json: { error: e.message }, status: :internal_server_error
      end
    end
  end
end