# frozen_string_literal: true

class Announcement
  class BlocksController < ApplicationController
    def create
      block = Announcement::Block.new(block_params.merge(parameters: JSON.parse(params[:parameters])))

      authorize block, policy_class: Announcement::BlockPolicy

      block.save!

      render json: { id: block.id, html: block.rendered_html }
    end

    def show
      block = Announcement::Block.find(params[:id])

      authorize block, policy_class: Announcement::BlockPolicy

      render json: { id: block.id, html: block.rendered_html }
    end

    def refresh
      block = Announcement::Block.find(params[:id])

      authorize block, policy_class: Announcement::BlockPolicy

      block.refresh!

      render html: block.render
    end

    private

    def block_params
      params.permit(:type, :announcement_id)
    end

  end

end
