# frozen_string_literal: true

module Api
  module V1
    class GenerateLoginUrlContract < Api::ApplicationContract
      params do
        required(:public_id).filled(:string)
      end
    end
  end
end
