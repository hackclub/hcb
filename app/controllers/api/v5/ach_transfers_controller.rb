# frozen_string_literal: true

module Api
  module V5
    class AchTransfersController < ApplicationController
      def show
        @ach_transfer = AchTransfer.find_by_public_id!(params[:id])

        # Read routes authorize on the field lattice rather than a per-version
        # `show?`. See ApplicationPolicy#show_any_attribute?.
        authorize @ach_transfer, :show_any_attribute?
      end

    end
  end
end
