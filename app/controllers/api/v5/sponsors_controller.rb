# frozen_string_literal: true

module Api
  module V5
    class SponsorsController < ApplicationController
      def index
        @sponsors = policy_scope(Sponsor).includes(:event).order(created_at: :desc)
        @sponsors = @sponsors.where(event: Event.where_public_id(params[:organization_id]).or(Event.where(slug: params[:organization_id]))) if params[:organization_id].present?
        @sponsors = paginate_cursor(@sponsors.to_a, &:public_id)
      end

      def show
        @sponsor = authorize Sponsor.find_by_public_id!(params[:id]), :show_any_attribute?
      end

    end
  end
end
