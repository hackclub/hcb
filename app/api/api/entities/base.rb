# frozen_string_literal: true

module Api
  module Entities
    class Base < Grape::Entity
      include Helpers::ExpandHelper

      expose :public_id, as: :id
      expose :object do |obj, options|
        self.class.object_type
      end
      expose :href do |obj, options|
        root = Rails.application.routes.url_helpers.root_url[0..-2] # remove trailing slash
        "#{root}/api/v3/#{self.class.object_type.pluralize}/#{obj.public_id}"
      end

      format_with(:iso_timestamp) { |dt| dt&.iso8601 }

      def self.format_as_date(&block)
        with_options(format_with: :iso_timestamp, &block)
      end

      def self.entity_name
        self.name.demodulize.titleize
      end

      delegate :object_type, to: :class

      def self.object_type
        self.entity_name.gsub(" ", "_").underscore
      end

      private

      def url_for_attached(attachment, transformations = nil)
        return nil unless attachment&.attached?

        if transformations.nil? || !attachment.variable?
          # Serve original attachment
          return Rails.application.routes.url_helpers.url_for attachment
        end

        Rails.application.routes.url_helpers.url_for(
          attachment.variant(transformations)
        )
      end

    end
  end
end
