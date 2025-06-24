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
    authorize @event, :update?
    params[:tiers]&.each do |id, tier_data|
      tier = @event.donation_tiers.find_by(id: id)
      next unless tier

      amount_cents = (tier_data[:amount_cents].to_f * 100).to_i
      tier.update(
        name: tier_data[:name],
        description: tier_data[:description],
        amount_cents: amount_cents
      )
    end

    redirect_to event_path(@event), notice: "Donation tiers updated successfully."
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
