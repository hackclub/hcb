# frozen_string_literal: true

module Api
  module V5
    class WiresController < ApplicationController
      include Api::V5::TransferCreation
      include Api::V5::ScopedResource

      scoped_resource Wire, organization_scope: :event, preload: [:event]

      def create
        event = find_organization!(params[:organization_id])
        attrs = permitted_attributes(Wire.new(event:))

        @record = event.wires.build(attrs.except(:file).merge(user: current_user))
        authorize @record

        return if refuse_above_sudo_threshold!(@record.usd_amount_cents, noun: "Wire transfers")

        ActiveRecord::Base.transaction do
          @record.save!
          attach_receipt!(@record.local_hcb_code, attrs[:file])
        end

        render :show, status: :created
      end

      require_oauth2_scope "transfers:write", :create
    end
  end
end
