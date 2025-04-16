class RafflesController < ApplicationController
  skip_after_action :verify_authorized, only: :create

  def new
  end

  def create
    Raffle.create!(user: current_user, program: params[:program])
  end
end
