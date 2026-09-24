# frozen_string_literal: true

module EventMappingEngine
  class Nuke
    def run
      return unless Rails.env.development?

      Fee.delete_all
      CanonicalEventMapping.delete_all
    end

  end
end
