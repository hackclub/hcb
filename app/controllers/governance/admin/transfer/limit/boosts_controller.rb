# frozen_string_literal: true

module Governance
  module Admin
    module Transfer
      class Limit
        class BoostsController < ApplicationController
          before_action :set_user

          def create
            limit = Governance::Admin::Transfer::Limit.find_by(user: @user)
            boost = Governance::Admin::Transfer::Limit::Boost.new(
              limit:,
              granted_by: current_user,
              amount_cents: Monetize.parse(params[:amount]).cents,
              duration_in_hours: params[:duration_in_hours],
              reason: params[:reason]
            )
            authorize boost

            if limit.nil?
              return redirect_back_or_to admin_user_path(@user), flash: { error: "#{@user.name} needs an admin transfer limit before it can be boosted." }
            end

            if boost.save
              redirect_back_or_to admin_user_path(@user), flash: { success: "Boosted admin transfer limit by #{boost.amount.format} until #{boost.expires_at.strftime("%b %-d, %Y %-l:%M %p %Z")}." }
            else
              redirect_back_or_to admin_user_path(@user), flash: { error: boost.errors.full_messages.to_sentence }
            end
          end

          def revoke
            boost = Governance::Admin::Transfer::Limit.find_by!(user: @user).boosts.find(params[:boost_id])
            authorize boost

            boost.revoke! if boost.active?

            redirect_back_or_to admin_user_path(@user), flash: { success: "Revoked #{boost.amount.format} admin transfer limit boost." }
          end

          private

          def set_user
            @user = User.friendly.find(params[:id])
          end

        end

      end
    end
  end
end
