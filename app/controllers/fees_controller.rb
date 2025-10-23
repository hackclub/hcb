# frozen_string_literal: true

class FeesController < ApplicationController
  include SetEvent

  before_action :set_event, only: %i[create]

  def create
    @fee = @event.fees.build(
      memo: fee_params[:memo],
      amount_cents_as_decimal: Monetize.parse(fee_params[:amount]).cents,
      event_sponsorship_fee: @event.revenue_fee,
      reason: :manual
    )

    authorize @fee

    if @fee.save
      redirect_to edit_event_url(@event, tab: :admin), flash: { success: "Fee charged to #{@event.name}" }
    else
      flash[:error] = @fee.errors.full_messages.to_sentence || "Fee could not be charged"
      redirect_to edit_event_url(@event, tab: :admin)
    end
  end

  private

  def fee_params
    params.require(:fee).permit(:amount, :memo)
  end

end
