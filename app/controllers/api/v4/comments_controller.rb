# frozen_string_literal: true

module Api
  module V4
    class CommentsController < ApplicationController
      def index
        @hcb_code = authorize HcbCode.find_by_public_id!(params[:transaction_id]), :show?
        @comments = policy_scope(@hcb_code.comments).includes(:user).order(created_at: :asc)
      end

      def create
        @hcb_code = HcbCode.find_by_public_id!(params[:transaction_id])

        admin_only = params[:admin_only] || false

        @comment = @hcb_code.comments.build(
          content: params[:content],
          user: current_user,
          admin_only: admin_only,
          file: params[:file]
        )

        authorize @comment

        @comment.save!

        render "show"
      end

    end
  end
end
