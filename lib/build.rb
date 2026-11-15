# frozen_string_literal: true

module Build
  class << self
    def commit_hash
      # Cache commit hash globally to avoid reading the file multiple times
      # rubocop:disable Style/GlobalVars
      $commit_hash ||=
        begin
          # This file is created by Hatchbox during deployment
          File.open("REVISION") do |file|
            file.read.strip.presence
          end
        rescue
          nil
        end
      $commit_hash ||= `git show --pretty=%H -q 2> /dev/null`.chomp
      # rubocop:enable Style/GlobalVars
    end

    def commit_dirty?
      # Assume not dirty in production to avoid unnecessary calls
      return false if Rails.env.production?

      @commit_dirty ||= `git diff --shortstat 2> /dev/null | tail -n1`.chomp.present?
    end

    def commit_name
      @commit_name ||=
        begin
          short_hash = commit_hash.present? ? commit_hash[0...7] : "unknown"
          commit_dirty? ? "#{short_hash}-dirty" : short_hash
        end
    end

    def timestamp
      # Cache timestamp globally to avoid reading the file multiple times
      # rubocop:disable Style/GlobalVars
      $build_timestamp ||=
        begin
          # This file is created by the production Dockerfile
          File.open(".build-timestamp") do |file|
            timestamp = file.read.strip
            next unless timestamp.present?

            Time.at(timestamp.to_i)
          end
        rescue
          nil
        end
      # `Time.now` will update every time Rails is (re)started, rather than
      # after each build.
      $build_timestamp ||= Time.now if Rails.env.production?
      $build_timestamp
      # rubocop:enable Style/GlobalVars
    end

    def age
      return if timestamp.nil?

      ApplicationController.helpers.distance_of_time_in_words timestamp, Time.now
    end

  end
end
