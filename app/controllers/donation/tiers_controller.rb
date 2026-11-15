# frozen_string_literal: true

class Donation
  class TiersController < ApplicationController
    include SetEvent
    include DonationPageSetup

    before_action :set_event, except: [:set_index]
    skip_before_action :signed_in_user, only: [:start]
    before_action :check_dark_param, only: [:start]
    before_action :check_background_param, only: [:start]
    before_action :hide_seasonal_decorations, only: [:start]

    def start
      authorize @event, :donation_page?

      return unless build_donation_page!(event: @event, params:, request:)

      @hide_flash = true
      render "donations/start_donation"
    end

    def set_index
      tier = Donation::Tier.find_by_hashid!(params[:id])
      return head status: :not_found unless tier

      authorize tier, :update?

      index = params[:index]

      tiers = tier.event.donation_tiers.order(:sort_index).to_a
      return head status: :bad_request if index < 0 || index >= tiers.size

      tiers.delete tier
      tiers.insert index, tier

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

      redirect_to edit_event_path(@event.slug, tab: "donations"),
                  flash: {
                    success: {
                      text: "Donation tier created successfully.",
                      link: edit_announcement_path(announcement),
                      link_text: "Create an announcement!"
                    }
                  }
    rescue ActiveRecord::RecordInvalid => e
      redirect_to edit_event_path(@event.slug, tab: "donations"),
                  flash: { error: e.message }
    end

    def update
      tiers = []
      params[:tiers]&.each_key do |id|
        tier = @event.donation_tiers.find_by(id: id)
        next unless tier

        authorize tier, :update?
        tiers << tier
      end

      tiers.each do |tier|
        data = tier_params(tier.id)

        tier.update!(
          name: data[:name],
          description: data[:description],
          amount_cents: (data[:amount_cents].to_f * 100).to_i,
          published: ActiveRecord::Type::Boolean.new.cast(data[:published])
        )
      end

      render json: { success: true, message: "Donation tiers updated successfully." }
    rescue ActiveRecord::RecordInvalid => e
      redirect_to edit_event_path(@event.slug, tab: "donations"),
                  flash: { error: e.message }
    end

    def destroy
      @tier = @event.donation_tiers.find(params[:format])
      authorize @tier, :destroy?

      @tier.destroy
      redirect_to edit_event_path(@event.slug, tab: "donations"),
                  flash: { success: "Donation tiers updated successfully." }
    rescue ActiveRecord::RecordInvalid => e
      redirect_to edit_event_path(@event.slug, tab: "donations"),
                  flash: { error: e.message }
    end

    private

    def check_dark_param
      if params[:dark].present? || cookies[:donation_dark]
        @dark = true
        cookies[:donation_dark] = true
      end
    end

    def check_background_param
      # because we're going to be injecting this value into a stylesheet,
      # we ensure that it's a hex code to prevent: https://css-tricks.com/css-security-vulnerabilities/
      @background = params[:background] unless (params[:background] =~ /\A[0-9a-fA-F]{6}\z/).nil?
    end

    def hide_seasonal_decorations
      @hide_seasonal_decorations = true
    end

    def tier_params(id)
      params
        .require(:tiers)
        .require(id.to_s)
        .permit(:name, :description, :amount_cents, :published)
    end

  end

end
