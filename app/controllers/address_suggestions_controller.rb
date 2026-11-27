# frozen_string_literal: true

# Backs the `address-autocomplete` Stimulus controller's dropdown.
class AddressSuggestionsController < ApplicationController
  def index
    skip_authorization # any signed-in user may look up an address
    render json: AddressSuggestionService.search(params[:q], country: params[:country])
  end

end
