# frozen_string_literal: true

module HackClub
  # The HQ org chart: who reports to whom, as a nested hash keyed by email prefix
  # ("gary" -> gary@hackclub.com) or usr_ public id. Consumed by the weekly
  # subordinate-summary mailer and by the Flipper groups in FlipperGroups.
  module OrgChart
    TREE = {
      "melanie": [
        "sierra",
        "usr_MVt1m1", # Alex DeForrest
        "rhys",
        "anish",
        {
          "gary": [
            "manu", "ruien", "luke", "samuelf",
            "usr_BetQLy", # Ian
            "usr_Jptm3Z", # Sam Poder
            "usr_73tAe4" # Albert
          ],
          "lucy": [
            "sean", "mattsoh", "briyan", "kris", "georgia",
            "usr_let591", # Alex Luo
          ],
          "paul": %w[sarvesh],
        }
      ]
    }.freeze

    # Short digest of the tree, folded into cache keys by callers (e.g.
    # FlipperGroups) so a deploy that edits TREE naturally busts caches keyed on
    # the resolved membership instead of serving the old set until the TTL lapses.
    DIGEST = Digest::SHA256.hexdigest(TREE.to_s)[0, 12].freeze

    # Every key (email prefix or usr_ public id) at or below `root_key`, inclusive
    # of the root. With no argument, walks the whole tree.
    def self.keys(root_key = nil)
      structure = root_key ? subtree_for(TREE, root_key) : TREE
      return [] if structure.nil?

      keys_in(structure)
    end

    # The same keys resolved to ids of existing users. An unresolvable key is
    # dropped (a stale key must not break a caller's flag check) but still
    # reported, so a typo that silently removes someone from a group is visible
    # in every environment rather than failing invisibly. `on_missing: :report`
    # records without raising, unlike the mailer path's dev/test-raising default.
    def self.user_ids(root_key = nil)
      keys(root_key).filter_map { |key| to_user(key, on_missing: :report)&.id }
    end

    # Manager User => [direct-report Users], for every manager in the tree.
    def self.layers
      flatten(TREE)
    end

    def self.keys_in(structure)
      case structure
      when Hash # person has subordinates
        structure.flat_map { |manager, subordinates| [manager] + keys_in(subordinates) }
      when Array # continue to next layer
        structure.flat_map { |person| keys_in(person) }
      else # leaf: a person with no subordinates
        [structure]
      end
    end
    private_class_method :keys_in

    # The sub-hash rooted at `target` (as `{ target => subordinates }`), or nil.
    def self.subtree_for(structure, target)
      case structure
      when Hash
        structure.each do |key, subordinates|
          return { key => subordinates } if key == target

          found = subtree_for(subordinates, target)
          return found if found
        end
        nil
      when Array
        structure.each do |person|
          found = subtree_for(person, target)
          return found if found
        end
        nil
      end
    end
    private_class_method :subtree_for

    def self.flatten(structure)
      case structure
      when Hash # person has subordinates
        structure.reduce({}) do |layers, (manager, subordinates)|
          layers.merge(
            to_layer(manager, subordinates),
            flatten(subordinates)
          )
        end
      when Array # continue to next layer
        structure.reduce({}) do |layers, person|
          layers.merge(flatten(person))
        end
      else # person has no subordinates
        {}
      end
    end
    private_class_method :flatten

    def self.to_layer(manager, subordinates)
      # Only the direct reports (one level down)
      subordinates = subordinates.flat_map do |sub|
        sub.is_a?(Hash) ? sub.keys : sub
      end

      manager = to_user(manager)
      subordinates = subordinates.map { |subordinate| to_user(subordinate) }.compact
      return {} if manager.nil?

      { manager => subordinates }
    end
    private_class_method :to_layer

    # Resolves a tree key to a User. A missing user is usually a typo in the tree.
    # `on_missing:` controls how that's surfaced:
    #   :raise  (default) - Rails.error.unexpected, which raises in dev/test and
    #                       records in prod. For callers that can afford to fail
    #                       loudly (the subordinate-summary mailer).
    #   :report           - Rails.error.report, which records in every env and
    #                       never raises. For callers that must not break on a
    #                       stale key (flag-group checks).
    def self.to_user(key, on_missing: :raise)
      user = case key
             when /\A#{User.get_public_id_prefix}.*\Z/
               User.find_by_public_id(key)
             else
               User.find_by(email: "#{key}@hackclub.com")
             end

      if user.nil?
        message = "[HackClub::OrgChart] User not found for key: #{key}"
        case on_missing
        when :raise then Rails.error.unexpected(message)
        when :report then Rails.error.report(StandardError.new(message), context: { key: })
        end
      end

      user
    end
    private_class_method :to_user
  end
end
