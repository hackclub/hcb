# frozen_string_literal: true

class PayrollPositionsController < ApplicationController
  def show
    @position = Payroll::Position.find_by_hashid!(params[:id])
    authorize @position, :welcome?

    @contract = @position.contracts.not_voided.order(created_at: :desc).first
    @contractor_party = @contract&.party(:contractor)
  end

end
