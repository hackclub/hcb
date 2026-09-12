# frozen_string_literal: true

module Api
  module V5
    class TagsController < ApplicationController
      def index
        @tags = policy_scope(Tag).includes(:event).order(:label)

        if params[:organization_id].present?
          @tags = @tags.where(event: Event.where_public_id(params[:organization_id]).or(Event.where(slug: params[:organization_id])))
        end

        @tags = paginate_cursor(@tags.to_a, &:public_id)
      end

      def show
        @tag = authorize Tag.find_by_public_id!(params[:id]), :show_any_attribute?
      end

      def create
        event = Event.find_by_public_id(params[:organization_id]) || Event.friendly.find(params[:organization_id])
        @tag = event.tags.build(permitted_attributes(Tag.new(event:)))

        authorize event, :create?, policy_class: TagPolicy
        @tag.save!

        render :show, status: :created
      end

      require_oauth2_scope "tags:write", :create

      def destroy
        tag = authorize Tag.find_by_public_id!(params[:id])
        tag.destroy!

        render json: { message: "Tag successfully deleted" }, status: :ok
      end

      require_oauth2_scope "tags:write", :destroy
    end
  end
end
