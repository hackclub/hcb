# frozen_string_literal: true

module Api
  module V5
    class AchTransfersController < ApplicationController
      include Api::V5::TransferCreation
      include Api::V5::ScopedResource

      scoped_resource AchTransfer, organization_scope: :event,
                                   preload: [:event, { creator: :organizer_positions }]

      def create
        event = find_organization!(params[:organization_id])
        attrs = permitted_attributes(AchTransfer.new(event:))

        @record = event.ach_transfers.build(attrs.except(:file).merge(creator: current_user))
        authorize @record

        return if refuse_above_sudo_threshold!(@record.amount, noun: "ACH transfers")

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
