# frozen_string_literal: true

module Governance
  module Admin
    module Transfer
      class LimitsController < ApplicationController
        before_action :set_user
        before_action :set_limit

        def update
          authorize @limit

          limit_amount_cents = (params[:limit_amount].to_f * 100).to_i
          @limit.amount_cents = limit_amount_cents
          @limit.save!
          redirect_back_or_to admin_user_path(@user), flash: { success: "Admin transfer limit updated to: $#{"%.2f" % (limit_amount_cents / 100.0)}" }
        end

        def history
          authorize @limit

          @history = @limit.versions
                           .reorder(created_at: :desc)
                           .page(params[:page])
                           .per(params[:per] || 25)

          changer_ids = @history.map(&:whodunnit).compact.uniq

          @changers = User
                      .where(id: changer_ids)
                      .index_by { |user| user.id.to_s }
        end

        private

        def set_user
          @user = User.friendly.find(params[:id])
        end

        def set_limit
          @limit = Governance::Admin::Transfer::Limit.find_by(user_id: @user.id) || Governance::Admin::Transfer::Limit.new(user: @user)
        end

      end
    end
  end
end
