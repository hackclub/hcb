# frozen_string_literal: true

class Comment
  class ReactionsController < ApplicationController
    before_action :set_comment

    def react
      authorize @comment
      emoji = params[:emoji]

      @comment.with_lock do
        existing_reaction = @comment.reactions.find_by(reactor: current_user, emoji:)

        if existing_reaction
          existing_reaction.destroy!
        else
          @comment.reactions.create!(emoji:, reactor: current_user)
        end
      end

      respond_to do |format|
        format.html { redirect_to @comment.commentable.is_a?(Event) ? edit_event_path(@comment.commentable, tab: :admin) : @comment.commentable }
        format.turbo_stream { render "comments/reactions/react", locals: { comment: @comment } }
      end
    end

    private

    def set_comment
      @comment = Comment.find(params[:id])
    end

  end

end
