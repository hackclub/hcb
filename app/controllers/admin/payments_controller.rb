# frozen_string_literal: true

module Admin
  class PaymentsController < Admin::BaseController
    def index
      @page = params[:page] || 1
      @per = params[:per] || 20

      relation = Payment.includes(:payee, :event)

      @q = params[:q].presence
      relation = relation.search_recipient(@q) if @q

      @state = params[:state].presence
      relation = relation.where(aasm_state: @state) if @state

      @count = relation.count
      @payments = relation.order(created_at: :desc).page(@page).per(@per)
    end

  end
end
