# frozen_string_literal: true

module Admin
  class FlaggedUsersController < Admin::BaseController
    def index
      @flagged_users = User.flagged.includes(:flagged_by).order(flagged_at: :desc)
    end

    def create
      user = User.find_by(email: params[:email].to_s.strip.downcase)

      if user.nil?
        flash[:error] = "No user found with that email."
      else
        user.flag!(reason: params[:reason].presence, flagged_by: current_user)
        flash[:success] = "#{user.email} has been flagged."
      end

      redirect_to admin_flagged_users_path
    end

    def destroy
      user = User.flagged.find(params[:id])
      user.unflag!

      flash[:success] = "#{user.email} has been unflagged."
      redirect_to admin_flagged_users_path
    end

  end
end
