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
          # that would confirm the organization exists. An organization that
          # doesn't exist returns empty for the same reason — 404 here would
          # distinguish "no such organization" from "not yours".
          #
          # `where_public_id` rather than `find_by_public_id`: we only need the
          # id to filter on, and loading the whole Event row to read it costs a
          # second query for nothing.
          @ach_transfers = @ach_transfers.where(event: Event.where_public_id(params[:organization_id]))
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
