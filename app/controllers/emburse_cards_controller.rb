# frozen_string_literal: true

class EmburseCardsController < ApplicationController
  include SetEvent
  before_action :set_event, only: [:status]

  before_action :set_emburse_card, only: :show
  skip_before_action :signed_in_user

  # GET /emburse_cards
  def index
    @emburse_cards = EmburseCard.all.includes(:event, :user).page params[:page]
    authorize @emburse_cards
  end

  # GET /emburse_cards/1
  def show
    authorize @emburse_card
    @emburse_transfers = @emburse_card.emburse_transfers
    @emburse_transactions = @emburse_card.emburse_transactions.order(transaction_time: :desc)
  end

  def status
    @emburse_card_requests = @event.emburse_card_requests.under_review
    @emburse_transfers = @event.emburse_transfers
  end

  private

  # Use callbacks to share common setup or constraints between actions.
  def set_emburse_card
    @emburse_card = EmburseCard.friendly.find(params[:id] || params[:emburse_card_id])
    @event = @emburse_card.event
  end

end
