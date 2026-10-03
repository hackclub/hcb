# frozen_string_literal: true

module Api
  module Helpers
    module ExpandHelper
      # By default, objects are "minimized". This will usually consist of just
      # an `id`, `href`, and `object` (api object type, e.g. "ach_transfer").
      #
      # The object can be optionally expanded or hidden using the `expand` or
      # `hide` query params. The `hide` query param is not documented publicly,
      # but is usable!
      #
      # When configuring a new Grape::Entity, you will want to use the following
      # two methods:
      # • `when_expanded`: Define exposures within its block to only expose
      #     those attributes when the object is expanded.
      # • `when_showing(Entities::Donation)`: Define collection exposures within
      #     its block to only show that collection once. This is important! It
      #     prevents endless recursion (which is likely since a lot of our
      #     entities provide circular references).
      #
      # When configuring a new route with Grape::API, you will want to passed in
      # the spread (use the ** operator) of the `type_expansion` helper method.
      # That helper method defines the initial `expand` and `hide` options. By
      # default, all objects will be minimized. Chances are, you'll want to have
      # some objects expanded by default for a specific endpoint. To do this,
      # simply pass in a an array of api object types (strings) under a `expand`
      # and/or `hide` key to the `type_expansion` helper method.
      # Example:
      #   present donations, with: Api::Entities::Donation,
      #                      **type_expansion(expand: %w[donation])

      def self.included(base)
        base.extend ClassMethods
      end

      module ClassMethods
        def should_expand?(entity = nil)
          proc do |object, options|
            # It is important that we assign self now, rather than as a  default
            # value in the `should_expand?` method's parameter, because this
            # allows us to get the `self` of the lowest descendent class rather
            # than the `self` of the class that implements the method. In other
            # words, `self` now would be an instance of `Entity::Donation`
            # rather than an instance of `Entity::LinkedObjectBase`.
            entity ||= self
            return false unless self.class.should_show? entity

            expand_types = options[:expand] || []
            (expand_types & get_types(entity)).any?
          end
        end

        def should_show?(entity)
          proc do |object, options|
            hide_types = options[:hide] || []
            (hide_types & get_types(entity)).none?
          end
        end

        def when_expanded(&block)
          with_options(if: should_expand?, &block)
        end

        def when_showing(entity, &block)
          with_options(if: should_show?(entity), &block)
        end

        def expose_associated(entity, as: nil, hide: nil, documentation: nil, &block)
          key = (as || entity.object_type || entity.to_s).to_sym
          docs = documentation || { type: entity }

          when_showing entity do
            expose key, documentation: docs do |obj, options|
              association_obj = block.call(obj, options)
              entity.represent(association_obj, options_hide(hide || self))
            end
          end
        end

      end

      def options_hide(entity)
        options_modify(:hide, entity)
      end

      def options_expand(entity)
        options_modify(:expand, entity)
      end

      private

      def options_modify(key, types)
        types = [types] unless types.is_a? Array
        types = types.map do |entity|
          get_types entity
        end.flatten.uniq
        hide_types = options[key]
        hide_types ||= []
        combined_types = hide_types + types
        options.merge(Hash[key, combined_types])
      end

      def get_types(entity)
        types = []
        if entity.is_a?(Entities::Base) || (entity.is_a?(Class) && entity <= Entities::Base)
          types << entity.object_type
        else
          types << entity.to_s
        end

        if entity.is_a?(Entities::LinkedObjectBase) || (entity.is_a?(Class) && entity <= Entities::LinkedObjectBase)
          types << Entities::LinkedObjectBase::API_LINKED_OBJECT_TYPE
        end

        types
      end

    end
  end
end
