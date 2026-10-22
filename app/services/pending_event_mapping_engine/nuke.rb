# frozen_string_literal: true

module PendingEventMappingEngine
  class Nuke
    def run
      return unless Rails.env.development?

      CanonicalPendingEventMapping.delete_all
    end

  end
end
