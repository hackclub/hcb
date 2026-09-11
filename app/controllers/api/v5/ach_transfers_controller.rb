# frozen_string_literal: true

module Api
  module V5
    class AchTransfersController < ApplicationController
      def index
        @ach_transfers = policy_scope(AchTransfer)
                         .includes(:event, creator: :organizer_positions)
                         .order(created_at: :desc)

        if params[:organization_id].present?
          # Filtering narrows what the scope already allows; it never widens it,
          # so an unreadable organization yields an empty page rather than a 403
          # that would confirm the organization exists.
          @ach_transfers = @ach_transfers.where(event: Event.find_by_public_id(params[:organization_id]))
        end

        @ach_transfers = @ach_transfers.limit(25)
      end

      def show
        @ach_transfer = AchTransfer.find_by_public_id!(params[:id])

        # Read routes authorize on the field lattice rather than a per-version
        # `show?`. See ApplicationPolicy#show_any_attribute?.
        authorize @ach_transfer, :show_any_attribute?
      end

    end
  end
end
