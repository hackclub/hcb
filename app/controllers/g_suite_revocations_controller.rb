# frozen_string_literal: true

class GSuiteRevocationsController < ApplicationController
  before_action :set_g_suite_revocation, only: [:destroy]

  def create
    @g_suite = GSuite.find(params[:g_suite_id])
    @revocation = @g_suite.revocations.build(revocation_params)

    authorize @revocation

    if @revocation.save
      redirect_to @g_suite, notice: "Revocation was successfully created."
    else
      flash[:error] = "Revocation could not be created."
      redirect_to g_suites_url
    end
  end

  def destroy
    authorize @g_suite_revocation

    if @g_suite_revocation.destroy
      flash[:success] = "Revocation was successfully destroyed."
      redirect_to g_suites_url
    else
      render :index, status: :unprocessable_entity
    end
  end

  private

  # Use callbacks to share common setup or constraints between actions.
  def set_g_suite_revocation
    @g_suite_revocation = GSuite::Revocation.find(params[:id])
  end

  def revocation_params
    params.require(:g_suite_revocation).permit(:reason, :other_reason)
  end

end
