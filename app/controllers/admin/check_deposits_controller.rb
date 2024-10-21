# frozen_string_literal: true

module Admin
  class CheckDepositsController < ApplicationController
    skip_after_action :verify_authorized # do not force pundit
    before_action :signed_in_admin

    layout "admin"

    def index
      @page = params[:page] || 1
      @per = params[:per] || 20
      @check_deposits = CheckDeposit.page(@page).per(@per).order(Arel.sql("column_id IS NULL AND increase_id IS NULL DESC, created_at DESC"))
    end

    def show
      @check_deposit = CheckDeposit.find(params[:id])
    end

    def submit
      @check_deposit = CheckDeposit.find(params[:id])
      ColumnService.get "/transfers/checks/#{params[:column_id]}"
      @check_deposit.update!(column_id: params[:column_id], status: :submitted)
      redirect_to admin_check_deposits_path, flash: { success: "Check deposit processed!" }
    rescue ActiveRecord::RecordInvalid
      flash.now[:error] = "Another check deposit has already been processed with this ID."
      render :show, status: :unprocessable_entity
    rescue Faraday::Error => e
      notify_airbrake(e)
      flash.now[:error] = "Something went wrong: #{e.response_body["message"]}"
      render :show, status: :unprocessable_entity
    rescue => e
      notify_airbrake(e)
      flash.now[:error] = "Something went wrong :("
      render :show, status: :unprocessable_entity
    end

    def reject
      @check_deposit = CheckDeposit.find(params[:id])
      @check_deposit.update!(status: :rejected, rejection_reason: params[:reason])
      redirect_to admin_check_deposits_path, flash: { success: "Check rejected :(" }
    end

  end
end
