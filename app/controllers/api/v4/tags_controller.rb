# frozen_string_literal: true

module Api
  module V4
    class TagsController < ApplicationController
      include SetEvent

      before_action :set_api_event, only: [:index, :create]
      before_action :set_tag, only: [:show, :destroy]

      def index
        authorize @event, :index_in_v4?
        @tags = @event.tags.order(created_at: :desc)
      end

      require_oauth2_scope("tags:read", :index)

      def show
        authorize @tag
      end

      require_oauth2_scope("tags:read", :show)

      def create
        @tag = @event.tags.build(params.permit(:label, :color, :emoji))
        authorize @event, policy_class: TagPolicy
        @tag.save!
        render :show, status: :created
      end

      require_oauth2_scope("tags:write", :create)

      def destroy
        authorize @tag
        @tag.destroy!
        render json: { message: "Tag successfully deleted" }, status: :ok
      end

      require_oauth2_scope("tags:write", :destroy)

      private

      def set_tag
        @tag = Tag.find_by_public_id!(params[:id])
        @event = @tag.event
      end

    end
  end
end
