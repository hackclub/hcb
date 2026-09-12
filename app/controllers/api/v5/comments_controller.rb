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
    end
  end
end
