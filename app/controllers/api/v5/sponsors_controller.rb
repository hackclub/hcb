# frozen_string_literal: true

module Api
  module V5
    class SponsorsController < ApplicationController
      include Api::V5::TransferCreation

      def index
        @sponsors = policy_scope(Sponsor).includes(:event).order(created_at: :desc)
        @sponsors = @sponsors.where(event: Event.where_public_id(params[:organization_id]).or(Event.where(slug: params[:organization_id]))) if params[:organization_id].present?
        @sponsors = paginate_cursor(@sponsors.to_a, &:public_id)
      end

      def show
        @sponsor = authorize Sponsor.find_by_public_id!(params[:id]), :show_any_attribute?
      end

      def create
        event = find_organization!(params[:organization_id])
        authorize event, :create?, policy_class: SponsorPolicy

        @sponsor = event.sponsors.build(permitted_attributes(Sponsor.new(event:)))
        authorize @sponsor
        @sponsor.save!

        render :show, status: :created
      end

      require_oauth2_scope "sponsors:write", :create
    end
  end
end
