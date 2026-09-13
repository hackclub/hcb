# frozen_string_literal: true

module Api
  module V5
    class ChecksController < ApplicationController
      include Api::V5::TransferCreation
      include Api::V5::ScopedResource

      scoped_resource IncreaseCheck, organization_scope: :event, preload: [:event]

      def create
        event = find_organization!(params[:organization_id])
        attrs = permitted_attributes(IncreaseCheck.new(event:))

        @record = event.increase_checks.build(
          attrs.except(:file, :amount_cents).merge(amount: attrs[:amount_cents], user: current_user)
        )
        authorize @record

        return if refuse_above_sudo_threshold!(@record.amount, noun: "Checks")

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
