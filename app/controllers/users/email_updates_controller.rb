# frozen_string_literal: true

module Users
  class EmailUpdatesController < ApplicationController
    def authorize_change
      @request = User::EmailUpdate.active.find_by!(authorization_token: params[:authorization_token])

      authorize @request

      @request.update!(authorized: true)

      if @request.confirmed?
        return redirect_to root_path, flash: { success: "We've updated your email address to #{@request.user.email}." }
      else
        return redirect_to root_path, flash: { success: "Authorized; please check your new email's inbox (#{@request.replacement}) to verify this change." }
      end
    rescue ActiveRecord::RecordNotFound => e
      flash[:error] = "This authorization token has expired, please request another."
    rescue ActiveRecord::RecordInvalid => e
      flash[:error] = @request.errors.full_messages.to_sentence
    end

    def verify
      @request = User::EmailUpdate.active.find_by!(verification_token: params[:verification_token])

      authorize @request

      @request.update!(verified: true)

      if @request.confirmed?
        return redirect_to root_path, flash: { success: "We've updated your email address to #{@request.user.email}." }
      else
        return redirect_to root_path, flash: { success: "Verified; please check your old email's inbox (#{@request.replacement}) to authorize this change." }
      end
    rescue ActiveRecord::RecordNotFound => e
      flash[:error] = "This authorization token has expired, please request another."
    rescue ActiveRecord::RecordInvalid => e
      flash[:error] = @request.errors.full_messages.to_sentence
    end

  end
end
