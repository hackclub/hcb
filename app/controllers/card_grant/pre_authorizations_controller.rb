# frozen_string_literal: true

module CardGrant
  class PreAuthorizationsController < ApplicationController
    before_action :set_card_grant

    def show

    end

    def update

    end

    private

    def set_card_grant
      @card_grant = CardGrant.find_by_hash_id!(params[:card_grant_id])
      @pre_authorization = @card_grant.pre_authorization

      raise ActiveRecord::RecordNotFound if @pre_authorization.nil?
    end

    def pre_authorization_params
      # reqire/permit whatever
    end

  end
end
