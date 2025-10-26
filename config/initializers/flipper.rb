# frozen_string_literal: true

Rails.application.configure do
  # @msw Disable preloading for feature-flags to save on db queries b/c we
  # aren't running many betas at the time of writing. If Flipper is used
  # extensively in the future, this can be changed
  config.flipper.preload = false

  # Setting to `true` or `:raise` will raise error when a feature doesn't exist.
  # Use `:warn` to log a warning instead.
  config.flipper.strict = false

  # Don't limit to 100 actors per feature
  config.flipper.actor_limit = false
end

Flipper::UI.configure do |config|
  config.actor_names_source = ->(keys) {
    grouped = {}

    keys.each do |key|
      # Flipper uses `"#{self.class.name};#{id}"` as the default identifier
      # (which we don't override).
      # https://github.com/flippercloud/flipper/blob/00bb6026aa668d5e6bc6390759a3572cf9678206/lib/flipper/identifier.rb#L14
      model, id = key.split(";", 2)

      # The contents of the `flipper_gates` table in production indicate that
      # these are the only classes we currently use.
      next unless %w[Event User].include?(model) && id =~ /\A\d+\z/

      grouped[model] ||= {}
      grouped[model][id.to_i] = key
    end

    actor_names = {}

    grouped.each do |model, mapping|
      case model
      when "User"
        User.where(id: mapping.keys).pluck(:id, :email, :full_name).each do |(id, email, full_name)|
          actor_names[mapping.fetch(id)] = CGI.escape_html(ActionMailer::Base.email_address_with_name(email, full_name))
        end
      when "Event"
        Event.where(id: mapping.keys).pluck(:id, :name).each do |(id, name)|
          actor_names[mapping.fetch(id)] = name
        end
      end
    end

    actor_names
  }
end
