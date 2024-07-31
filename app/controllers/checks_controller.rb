# frozen_string_literal: true

class ChecksController < ApplicationController
  before_action :set_check
  skip_before_action :signed_in_user, only: :show

  def show
    authorize @check

    redirect_to @check.local_hcb_code
  end

  private

  def set_check
    @check = Check.includes(:creator).find(params[:id] || params[:check_id])
    @event = @check.event
  end

end
