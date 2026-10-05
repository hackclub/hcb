# frozen_string_literal: true

class ChecksController < ApplicationController
  before_action :set_check

  def show
    authorize @check

    redirect_to @check.local_hcb_code
  end

  private

  def set_check
    @check = Check.find(params[:id] || params[:check_id])
  end

end
