# frozen_string_literal: true

class GSuiteRevocationsController < ApplicationController
  before_action :set_g_suite_revocation, only: [:destroy]

  def create
    @g_suite = GSuite.find(params[:g_suite_id])
    @revocation = @g_suite.build_revocation(revocation_params.merge(reason: :other))

    authorize @revocation

    if @revocation.save
      flash[:success] = "Revocation was successfully created."
    else
      flash[:error] = "Revocation could not be created."
    end
    redirect_to google_workspace_process_admin_path(@g_suite)
  end

  def destroy
    authorize @g_suite_revocation
    @g_suite = @g_suite_revocation.g_suite

    if @g_suite_revocation.destroy
      flash[:success] = "Revocation was successfully canceled."
    else
      flash[:error] = "Revocation could not be canceled."
    end
    redirect_to google_workspace_process_admin_path(@g_suite)
  end

  private

  def set_g_suite_revocation
    @g_suite_revocation = GSuite.find(params[:id])&.revocation
  end

  def revocation_params
    params.require(:g_suite_revocation).permit(:other_reason)
  end

end
