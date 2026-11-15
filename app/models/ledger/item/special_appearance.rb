# frozen_string_literal: true

class Ledger
  class Item
    # This registry is APPEND-ONLY: a key that has ever been written to the
    # column must stay here, or historical items lose their appearance.
    #
    # Every attribute but the key is optional, and each one an appearance
    # leaves out falls back to how the item would have looked anyway.
    #
    # The legacy transaction views read their own copy of the grant definitions
    # from Disbursement::SPECIAL_APPEARANCES; that hash goes away with them.
    class SpecialAppearance
      attr_reader :key, :title, :memo, :css_class, :icon, :qualifier

      def initialize(key:, title: nil, memo: nil, css_class: nil, icon: nil, qualifier: nil)
        @key = key.to_s
        @title = title
        @memo = memo
        @css_class = css_class
        @icon = icon
        @qualifier = qualifier

        freeze
      end

      def applies_to?(linked_object)
        qualifier.present? && qualifier.call(linked_object)
      end

      # Anything serializing the attribute wants the key, not the object's
      # attributes — most importantly paper_trail, which would otherwise write the
      # whole appearance (and an empty hash for its lambda) into every version's
      # object_changes.
      def as_json(*)
        key
      end

      def self.fund_qualifier(event_ids, since = nil)
        return nil if event_ids.empty?

        lambda do |linked_object|
          next false unless linked_object.is_a?(Disbursement::Incoming)
          next false unless linked_object.source_event_id.in?(event_ids)
          next false if since && linked_object.created_at <= since

          true
        end
      end

      ALL = [
        new(
          key: :hackathon_grant,
          title: "Hackathon grant",
          memo: "💰 Hackathon grant from Hack Club",
          css_class: "transaction--fancy",
          icon: "purse",
          qualifier: fund_qualifier([EventMappingEngine::EventIds::HACKATHON_GRANT_FUND])
        ),
        new(
          key: :winter_hardware_wonderland,
          title: "Winter Hardware Wonderland grant",
          memo: "❄️ Winter Hardware Wonderland Grant",
          css_class: "transaction--icy",
          icon: "freeze",
          qualifier: fund_qualifier([EventMappingEngine::EventIds::WINTER_HARDWARE_WONDERLAND_GRANT_FUND])
        ),
        new(
          key: :argosy_grant_2024,
          title: "Grant from the Argosy Foundation",
          memo: "🤖 Argosy Foundation Rookie / Hardship Grant",
          css_class: "transaction--fancy",
          icon: "sam",
          # the same organization was used for multiple years. prior years didn't have this appearance.
          qualifier: fund_qualifier([EventMappingEngine::EventIds::ARGOSY_GRANT_FUND, EventMappingEngine::EventIds::ARGOSY_GRANT_FUND_2025], Date.new(2024, 9, 1))
        ),
        new(
          key: :first_transparency_grant,
          title: "FIRST® Transparency grant",
          memo: "🤖 FIRST® Transparency Grant",
          css_class: "transaction--frc",
          icon: "sam",
          qualifier: fund_qualifier([EventMappingEngine::EventIds::FIRST_TRANSPARENCY_GRANT_FUND])
        ),
        new(
          key: :gene_haas_grant,
          title: "Grant from Gene Haas",
          memo: "Gene Haas Grant",
          css_class: "transaction--genehaas",
          icon: "sam",
          qualifier: fund_qualifier([EventMappingEngine::EventIds::GENE_HAAS_GRANT_FUND])
        ),
        new(
          key: :card_grant,
          icon: "bag",
          qualifier: lambda { |linked_object|
            next false unless linked_object.class.in?([Disbursement::Outgoing, Disbursement::Incoming])

            # TODO: add source_ledger and destination_ledger to disbursement and replace these
            linked_object.source_subledger&.card_grant.present? || linked_object.destination_subledger&.card_grant.present?
          }
        )
      ].freeze

      BY_KEY = ALL.index_by(&:key).freeze

      def self.keys
        BY_KEY.keys
      end

      # Unknown keys resolve to nil rather than raising: a row written by a newer
      # deploy (or by hand) should render plainly, not break the whole ledger.
      def self.find_by_key(key)
        BY_KEY[key.to_s.presence]
      end

      def self.find_by_linked_object(linked_object)
        return nil if linked_object.nil?

        ALL.find { |appearance| appearance.applies_to?(linked_object) }
      end

      # Casts the `special_appearance` string column to a SpecialAppearance and
      # back, so the attribute reads as an object everywhere while still being
      # stored — and queried — as its key.
      class Type < ActiveModel::Type::Value
        def type
          :string
        end

        def cast(value)
          value.is_a?(SpecialAppearance) ? value : SpecialAppearance.find_by_key(value)
        end

        def serialize(value)
          cast(value)&.key
        end

      end

    end

  end

end
