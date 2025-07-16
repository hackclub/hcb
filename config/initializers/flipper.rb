# frozen_string_literal: true

Rails.application.configure do
  # @msw Disable preloading for feature-flags to save on db queries b/c we
  # aren't running many betas at the time of writing. If Flipper is used
  # extensively in the future, this can be changed
  config.flipper.preload = false

  # Setting to `true` or `:raise` will raise error when a feature doesn't exist.
  # Use `:warn` to log a warning instead.
  config.flipper.strict = :warn

  # Don't limit to 100 actors per feature
  config.flipper.actor_limit = false
end
