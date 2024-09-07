# frozen_string_literal: true

module StripeCards
  class PersonalizationDesignsController < ApplicationController
    before_action :set_personalization_design

    def show
      authorize @design
    end

    def make_common
      authorize @design

      @design.update!(common: true, event: nil)
      flash[:success] = "Design #{@design.name} is now common."

      redirect_back fallback_location: stripe_card_personalization_designs_admin_index_path
    end

    def make_private
      authorize @design

      @design.update!(common: false)
      flash[:success] = "Design #{@design.name} is now private."

      redirect_back fallback_location: stripe_card_personalization_designs_admin_index_path
    end

    private

    def set_personalization_design
      @design = StripeCard::PersonalizationDesign.find(params[:id])
    end

  end
end
