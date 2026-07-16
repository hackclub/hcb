# frozen_string_literal: true

module Admin
  class PayrollPositionsController < Admin::BaseController
    def index
      @page = params[:page] || 1
      @per = params[:per] || 20

      relation = Payroll::Position.includes(:payee, :event)

      @q = params[:q].presence
      relation = relation.search_recipient(@q) if @q

      @state = params[:state].presence
      relation = relation.where(aasm_state: @state) if @state

      @count = relation.count
      @positions = relation.order(Arel.sql("CASE WHEN aasm_state = 'under_review' THEN 0 ELSE 1 END, created_at DESC")).page(@page).per(@per)
    end

    # There is no "approve" action here: HCB approves a contractor by signing
    # their contract as HCB (see Payroll::Position#on_contract_party_signed),
    # from the contract's own signing page.
    def reject
      position = Payroll::Position.find(params[:id])
      position.mark_rejected!
      redirect_back fallback_location: admin_payroll_positions_path, flash: { success: "Contractor rejected." }
    rescue AASM::InvalidTransition
      redirect_back fallback_location: admin_payroll_positions_path, flash: { error: "This contractor can no longer be rejected." }
    end

  end
end
