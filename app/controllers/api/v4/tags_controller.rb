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

      def show
        authorize @tag
      end

      def create
        @tag = @event.tags.build(params.permit(:label, :color, :emoji))
        authorize @tag
        @tag.save!
        render :show, status: :created
      end

      def destroy
        authorize @tag
        @tag.destroy!
        render json: { message: "Tag successfully deleted" }, status: :ok
      end

      private

      def set_tag
        @tag = Tag.find_by_public_id!(params[:id])
        @event = @tag.event
      end

    end
  end
end
