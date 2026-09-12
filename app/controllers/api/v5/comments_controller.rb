# frozen_string_literal: true

module Api
  module V5
    class CommentsController < ApplicationController
      # Comments hang off a transaction rather than an organization, so the
      # transaction is authorized and `policy_scope` then applies CommentPolicy's
      # own filtering (admin-only comments) within it. The base controller only
      # verifies authorization outside index, so index opts back in — both
      # checks run here.
      after_action :verify_authorized, only: :index

      def index
        item = authorize Ledger::Item.find_by_public_id!(params[:transaction_id]), :show_any_attribute?

        @comments = policy_scope(item.comments).includes(:user).order(created_at: :asc)
        @comments = paginate_cursor(@comments.to_a, &:public_id)
      end

      require_oauth2_scope "comments:read", :index

      def create
        item = Ledger::Item.find_by_public_id!(params[:transaction_id])
        @comment = item.comments.build(permitted_attributes(Comment.new(commentable: item)).merge(user: current_user))

        authorize @comment
        @comment.save!

        render :show, status: :created
      end

      require_oauth2_scope "comments:write", :create
    end
  end
end
