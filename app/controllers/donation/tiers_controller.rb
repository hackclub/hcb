# frozen_string_literal: true

class Donation
  class TiersController < ApplicationController
    include SetEvent
    include DonationPageSetup

    before_action :set_event, except: [:set_index]

    def index
      @tiers = @event.donation_tiers
    end

    def start
      authorize @event, :donation_page?

      return unless build_donation_page!(event: @event, params:, request:)

      @hide_flash = true
      render "donations/start_donation"
    end

    def set_index
      tier = Donation::Tier.find_by(id: params[:id])
      authorize tier, :update?

      index = params[:index]

      # get all the tiers as an array
      tiers = tier.event.donation_tiers.order(:sort_index).to_a

      return head status: :bad_request if index < 0 || index >= tiers.size

      # switch the position *in the in-memory array*
      tiers.delete tier
      tiers.insert index, tier

      # persist the sort order
      ActiveRecord::Base.transaction do
        tiers.each_with_index do |op, idx|
          op.update(sort_index: idx)
        end
      end

      render json: tiers.pluck(:id)
    end

    def create
      @tier = @event.donation_tiers.new(
        name: "Untitled tier",
        amount_cents: 1000,
        description: "",
        sort_index: @event.donation_tiers.maximum(:sort_index).to_i + 1,
        published: false
      )
      
      authorize @tier, :create?
      @tier.save!

      announcement = Announcement::Templates::NewDonationTier.new(
        donation_tier: @tier,
        author: current_user
      ).create

      redirect_back fallback_location: edit_event_path(@event.slug), flash: { success: { text: "Donation tier created successfully.", link: edit_announcement_path(announcement), link_text: "Create an announcement!" } }
    rescue ActiveRecord::RecordInvalid => e
      redirect_back fallback_location: edit_event_path(@event.slug), flash: { error: e.message }
    end

    def update
      tiers = []
      params[:tiers]&.each do |id, tier_data|
        tier = @event.donation_tiers.find_by(id: id)
        authorize tier, :update?
        tiers << tier
      end

      puts "THESE ARE THE TIERS"
      puts params[:tiers].inspect

      tiers.each do |tier|
        tier_data = params[:tiers][tier.id.to_s]
        tier.update(
          name: tier_data[:name],
          description: tier_data[:description],
          amount_cents: (tier_data[:amount_cents].to_f * 100).to_i,
          published: ActiveRecord::Type::Boolean.new.cast(tier_data[:published])
        )
      end

      render json: { success: true, message: "Donation tiers updated successfully." }
    rescue ActiveRecord::RecordInvalid => e
      redirect_back fallback_location: edit_event_path(@event.slug), flash: { error: e.message }
    end

    def destroy
      @tier = @event.donation_tiers.find(params[:format])
      authorize @tier, :destroy?

      @tier.destroy
      redirect_back fallback_location: edit_event_path(@event.slug), flash: { success: "Donation tiers updated successfully." }
    rescue ActiveRecord::RecordInvalid => e
      redirect_back fallback_location: edit_event_path(@event.slug), flash: { error: e.message }
    end

  end

end
