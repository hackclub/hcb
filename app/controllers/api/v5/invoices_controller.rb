# frozen_string_literal: true

module Api
  module V5
    class InvoicesController < ApplicationController
      include Api::V5::TransferCreation
      include Api::V5::ScopedResource

      scoped_resource Invoice, organization_scope: :sponsor, preload: [:event]

      def create
        event = find_organization!(params[:organization_id])
        authorize event, :create?, policy_class: InvoicePolicy

        sponsor = authorize Sponsor.find_by_public_id!(params[:sponsor_id])
        attrs = permitted_attributes(Invoice.new(sponsor:))

        @record = ::InvoiceService::Create.new(
          event_id: event.id,
          due_date: attrs[:due_date].to_datetime,
          item_description: attrs[:item_description],
          item_amount: attrs[:item_amount],
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

        render :show, status: :created
      end

      require_oauth2_scope "invoices:write", :create
    end
  end
end
