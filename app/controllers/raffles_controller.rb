# frozen_string_literal: true

class RafflesController < ApplicationController
  skip_before_action :signed_in_user, only: [:new, :create]
  before_action :signed_in_or_unverified_user, only: [:new, :create]
  skip_after_action :verify_authorized, only: [:new, :create]

  def new
  end

  def create
    if Raffle.where(user: current_user(allow_unverified: true), program: params[:program]).any?
      flash[:success] = "Raffle joined!"

      respond_to do |format|
        format.turbo_stream { render turbo_stream: turbo_stream.refresh(request_id: nil) }
        format.html do
          redirect_back_or_to root_path
        end
      end
    else
      raffle = Raffle.new(user: current_user(allow_unverified: true), program: params[:program])
      if raffle.save
        flash[:success] = "Raffle joined!"
        respond_to do |format|
          format.turbo_stream { render turbo_stream: turbo_stream.refresh(request_id: nil) }
          format.html do
            redirect_back_or_to root_path
          end
        end
      else
        flash[:error] = raffle.errors.full_messages.to_sentence
        redirect_to new_raffle_path
      end
    end
  end

end
