class Donation::TiersController < ApplicationController
  before_action :set_event

  def index
    @tiers = @event.donation_tiers
  end

  def create
    authorize @event, :update?

    @tier = @event.donation_tiers.new(
      name: "Untitled tier",
      amount_cents: 1000,
      description: "",
      image_url: nil,
      position: @event.donation_tiers.count + 1
    )
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
    @event = Event.where(slug: params[:event_id]).first
    render json: { error: "Event not found" }, status: :not_found unless @event
  end

end
