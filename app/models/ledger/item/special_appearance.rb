# frozen_string_literal: true

class Ledger
  class Item
    # A cosmetic treatment for a ledger item — a nicer memo, icon, row styling,
    # and title for items belonging to a specific grant program.
    #
    # An item's appearance is decided once, from its linked object, and persisted
    # to `ledger_items.special_appearance` as the appearance's key. Everything
    # that *reads* an appearance reads that column; the qualifiers below only run
    # when assigning one, so they never cost anything on a page render.
    #
    # This registry is APPEND-ONLY: a key that has ever been written to the column
    # must stay here, or historical items lose their appearance. To stop applying
    # one to new items, drop its `qualifier` rather than deleting the entry.
    #
    # Every attribute but the key is optional, and each one an appearance leaves
    # out falls back to how the item would have looked anyway — so an appearance
    # can override just the icon, or just the memo.
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

      # An appearance without a qualifier is retired: still rendered for items
      # already carrying it, never assigned to a new one.
      def applies_to?(object)
        qualifier.present? && qualifier.call(object)
      end

      # Anything serializing the attribute wants the key, not the object's
      # innards — most importantly paper_trail, which would otherwise write the
      # whole appearance (and an empty hash for its lambda) into every version's
      # object_changes.
      def as_json(*)
        key
      end

      # Most appearances mark transfers out of a particular fund, so they pass
      # `funds` (and optionally `since`) instead of writing their own qualifier.
      #
      # The type guard is on Disbursement::Shared, not Disbursement: a ledger item's
      # linked object is always a Disbursement::Incoming/Outgoing lens, and those
      # descend from Disbursement::Base rather than Disbursement. Shared is the one
      # thing all three have in common.
      def self.fund_qualifier(event_ids, since = nil)
        return nil if event_ids.empty?

        lambda do |object|
          next false unless object.is_a?(Disbursement::Shared)
          next false unless object.source_event_id.in?(event_ids)
          next false if since && object.created_at <= since

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
          qualifier: ->(object) { object.is_a?(Disbursement::Shared) && object.card_grant.present? }
        )
      ].freeze

      BY_KEY = ALL.index_by(&:key).freeze

      # Unknown keys resolve to nil rather than raising: a row written by a newer
      # deploy (or by hand) should render plainly, not break the whole ledger.
      def self.find(key)
        key.present? ? BY_KEY[key.to_s] : nil
      end

      def self.keys
        BY_KEY.keys
      end

      # The appearance a linked object earns, if any. Only called when assigning.
      def self.for(object)
        return nil if object.nil?

        ALL.find { |appearance| appearance.applies_to?(object) }
      end

      # Casts the `special_appearance` string column to a SpecialAppearance and
      # back, so the attribute reads as an object everywhere while still being
      # stored — and queried — as its key.
      class Type < ActiveModel::Type::Value
        def type
          :string
        end

        def cast(value)
          value.is_a?(SpecialAppearance) ? value : SpecialAppearance.find(value)
        end

        def serialize(value)
          cast(value)&.key
        end

      end

    end

  end

end
