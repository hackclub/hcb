# frozen_string_literal: true

module Api
  module Entities
    class Merchant < Grape::Entity
      expose :name
      expose :smart_name
      expose :country
      expose :network_id
    end
  end
end
