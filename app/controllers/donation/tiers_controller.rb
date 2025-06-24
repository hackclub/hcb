class Donation::TiersController < ApplicationController
  before_action :set_event

  def index
    @tiers = @event.donation_tiers
  end

  def create
    @tier = @event.donation_tiers.new(tier_params)
    if @tier.save
      render json: @tier, status: :created
    else
      render json: { errors: @tier.errors.full_messages }, status: :unprocessable_entity
    end
  end

  def update
    @tier = @event.donation_tiers.find(params[:id])
    if @tier.update(tier_params)
      render json: @tier
    else
      render json: { errors: @tier.errors.full_messages }, status: :unprocessable_entity
    end
  end

  def destroy
    @tier = @event.donation_tiers.find(params[:id])
    @tier.destroy
    head :no_content
  end

  private

  def set_event
    @event = Event.find_by_public_id(params[:event_id])
  end

  def tier_params
    params.require(:donation_tier).permit(:name, :amount_cents, :description, :image_url, :position)
  end
end
