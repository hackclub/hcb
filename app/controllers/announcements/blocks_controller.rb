# frozen_string_literal: true

module Announcements
  class BlocksController < ApplicationController
    before_action :set_block, except: :create

    def create
      block = Announcement::Block.new(block_params.merge(parameters: JSON.parse(params[:parameters])))

      authorize block, policy_class: Announcement::BlockPolicy

      unless block.save
        return render json: { errors: block.errors.map(&:full_message) }, status: :bad_request
      end

      render json: { id: block.id, html: block.render }
    end

    def show
      authorize @block, policy_class: Announcement::BlockPolicy

      render json: { id: @block.id, html: @block.render }
    end

    def edit
      authorize @block, policy_class: Announcement::BlockPolicy

      render @block.modal, layout: false, locals: { block: @block }
    end

    def update
      authorize @block, policy_class: Announcement::BlockPolicy

      unless @block.update(parameters: JSON.parse(params[:parameters]))
        return render json: { errors: @block.errors.map(&:full_message) }, status: :bad_request
      end

      render turbo_stream: turbo_stream.replace("block_#{@block.id}", partial: @block.partial, locals: @block.locals)
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
