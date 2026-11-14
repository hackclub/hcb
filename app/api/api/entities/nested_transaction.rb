# frozen_string_literal: true

module Api
  module Entities
    class NestedTransaction < Transaction
      unexpose :organization, *LINKED_OBJECT_TYPES

      def self.object_type
        Transaction.object_type
      end

    end
  end
end
