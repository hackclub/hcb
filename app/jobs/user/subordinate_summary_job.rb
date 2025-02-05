# frozen_string_literal: true

# I absolutely HATE the term "subordinate". However, I decided to use it in this
# context because it is more descriptive than "direct report". I am open to
# suggestions for a better term.
class User
  class SubordinateSummaryJob < ApplicationJob
    queue_as :low

    HQ_ORG_TREE = {
      "zach": [
        "dev",
        "alexren",
        "malted",
        "jared",
        {
          "graham": [
            "fayd",
            "marios",
            "shubham",
            "cheru",
            "josias",
            "usr_Jptmoo" # Shubham Patil
          ],
          "melanie": [
            "dylan",
            "kris",
            "dawn",
            {
              "gary": [
                "ian", "sam", "manu", "ruien",
                "usr_73tAe4" # Albert
              ],
              "daisy": [
                "leow", "aryan", "sarvesh", "rhys", "anish", "sean", "arianna",
                "usr_MVt1m1", # Alex DeForrest
                "usr_let591", # Alex Luo
              ],
              "paul": %w[lucy],
            }
          ],
        }
      ]
    }.freeze

    def perform
      self.class.org_layers.each do |manager, subordinates|
        User::SubordinateSummaryMailer.weekly(manager:, subordinates:).deliver_later
      end
    end

    def self.org_layers
      flatten(HQ_ORG_TREE)
    end

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
      else
        # User has no subordinates
        {}
      end
    end

    def self.to_layer(manager, subordinates)
      # Only get one level of subordinates (direct reports)
      subordinates = subordinates.flat_map do |sub|
        sub.is_a?(Hash) ? sub.keys : sub
      end

      # Convert them to User records
      manager = to_user(manager)
      subordinates = subordinates.map { |subordinate| to_user(subordinate) }.compact
      return {} if manager.nil?

      { manager => subordinates }
    end

    def self.to_user(key)
      user = case key
             when /\A#{User.get_public_id_prefix}.*\Z/
               User.find_by_public_id(key)
             else
               User.find_by(email: "#{key}@hackclub.com")
             end

      if user.nil?
        Rails.error.report("[HQ Subordinate Summary Job] User not found for key: #{key}")
      end

      user
    end

  end

end
