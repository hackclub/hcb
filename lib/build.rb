# frozen_string_literal: true

module Build
  class << self
    def commit_hash
      # https://coolify.io/docs/knowledge-base/environment-variables#source-commit
      @commit_hash ||= ENV["SOURCE_COMMIT"] || `git show --pretty=%H -q 2> /dev/null`.chomp
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
      $build_timestamp ||= # rubocop:disable Style/GlobalVars
        begin
          File.open(".build-timestamp") do |file|
            timestamp = file.read.strip
            next unless timestamp.present?

            Time.at(timestamp.to_i)
          end
        rescue
          nil
        end
    end

    def age
      return unless timestamp.present?

      ApplicationController.helpers.distance_of_time_in_words timestamp, Time.now
    end

  end
end
