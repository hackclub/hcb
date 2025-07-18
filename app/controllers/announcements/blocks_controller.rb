# frozen_string_literal: true

module Announcements
  class BlocksController < ApplicationController
    before_action :set_block, except: :create

    def create
      block = Announcement::Block.new(block_params.merge(parameters: JSON.parse(params[:parameters])))

      authorize block, policy_class: Announcement::BlockPolicy

      block.save!

      render json: { id: block.id, html: block.rendered_html }
    end

    def show
      authorize @block, policy_class: Announcement::BlockPolicy

      render json: { id: @block.id, html: @block.rendered_html }
    end

    def refresh
      authorize @block, policy_class: Announcement::BlockPolicy

      @block.refresh!

      render html: @block.render
    end

    private

    def set_block
      @block = Announcement::Block.find(params[:id])
    end

    def block_params
      params.permit(:type, :announcement_id)
    end

  end

end
