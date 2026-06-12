# frozen_string_literal: true

# == Schema Information
#
# Table name: event_affiliations
#
#  id              :bigint           not null, primary key
#  affiliable_type :string           not null
#  metadata        :jsonb            not null
#  name            :string           not null
#  created_at      :datetime         not null
#  updated_at      :datetime         not null
#  affiliable_id   :bigint           not null
#
# Indexes
#
#  index_event_affiliations_on_affiliable  (affiliable_type,affiliable_id)
#
class Event
  class Affiliation < ApplicationRecord
    include Hashid::Rails
    hashid_config salt: ""

    include ActionView::Helpers::TextHelper

    belongs_to :affiliable, polymorphic: true

    store_accessor :metadata, :league, :team_number, :size, :venue_name, :team_name, :role

    scope :robotics, -> { where(name: %w[first vex]) }
    scope :nonempty, -> { where.not(metadata: {}) }

    validate :metadata_contains_required_fields

    def display_name
      case name
      when "first"
        "FIRST"
      when "vex"
        "VEX"
      when "hack_club"
        "Hack Club"
      end
    end

    def is_first?
      name == "first"
    end

    def is_vex?
      name == "vex"
    end

    def is_hack_club?
      name == "hack_club"
    end

    def size
      super&.to_i
    end

    def to_s
      [display_name, league&.upcase, team_number, size&.positive? ? pluralize(size, "people") : nil].compact.join(" – ")
    end

    def tba_team_info
      return nil unless is_first? && team_number.present?

      self.class.tba_lookup(league, team_number)
    end

    def tba_team_name
      tba_team_info&.dig(:team_name)
    end

    def tba_avatar
      tba_team_info&.dig(:avatar)
    end

    # Returns the Event whose FIRST affiliation matches the user's FIRST
    # affiliation by league + team_number, or nil. Users only have at most one
    # FIRST affiliation today (the /first/welcome form allows only one), so a
    # `.first` lookup is sufficient.
    def self.matching_first_event_for(user)
      aff = user&.affiliations&.find_by(name: "first")
      return nil unless aff&.league.present? && aff&.team_number.present?

      Event.joins(:affiliations)
           .where(affiliations: { name: "first" })
           .where("affiliations.metadata->>'league' = ?", aff.league)
           .where("affiliations.metadata->>'team_number' = ?", aff.team_number)
           .first
    end

    # True when the user and event share a FIRST affiliation
    # (same league + team_number). Doesn't consider membership.
    def self.first_affiliation_matches?(user, event)
      return false if user.nil? || event.nil?

      aff = user.affiliations.find_by(name: "first")
      return false unless aff&.league.present? && aff&.team_number.present?

      event.affiliations
           .where(name: "first")
           .where("metadata->>'league' = ?", aff.league)
           .where("metadata->>'team_number' = ?", aff.team_number)
           .exists?
    end

    # True when the user has a matching FIRST affiliation with the event AND
    # is not already an organizer of it. Used to gate both the "Request to
    # join" UI and the controller endpoint that creates the invite request.
    def self.eligible_to_request_invite?(user, event)
      return false if user.nil? || event.nil?
      return false if event.users.exists?(id: user.id)

      first_affiliation_matches?(user, event)
    end

    TBA_BASE_URL = "https://www.thebluealliance.com/api/v3"

    def self.tba_lookup(league, team_number)
      league = league.to_s.downcase
      team_number = team_number.to_s

      conn = Faraday.new(url: TBA_BASE_URL) do |f|
        f.headers["X-TBA-Auth-Key"] = Credentials.fetch(:THE_BLUE_ALLIANCE, :API_KEY)
      end

      team_key = "frc#{team_number}"
      team_response = conn.get("team/#{team_key}")

      return nil unless team_response.success?

      team_data = JSON.parse(team_response.body)

      avatar = nil
      media_response = conn.get("team/#{team_key}/media/#{Date.today.year}")
      if media_response.success?
        media = JSON.parse(media_response.body)
        avatar_media = media.find { |m| m["type"] == "avatar" }
        if avatar_media
          base64 = avatar_media.dig("details", "base64Image")
          avatar = base64.present? ? "data:image/png;base64,#{base64}" : avatar_media["direct_url"].presence
        end
      end

      {
        league: league,
        team_number: team_number,
        team_name: team_data["nickname"],
        avatar: avatar
      }
    end

    private

    def metadata_contains_required_fields
      required_fields = case name
                        when "first"
                          ["league", "team_number"]
                        when "vex"
                          ["league", "team_number", "size"]
                        when "hack_club"
                          ["venue_name", "size"]
                        else
                          return errors.add(:name, "is not a valid affiliation")
                        end

      missing_fields = required_fields.select { |field| metadata[field].nil? }
      if missing_fields.any?
        errors.add(:metadata, "is missing fields: #{missing_fields.to_sentence}")
      end
    end

  end

end
