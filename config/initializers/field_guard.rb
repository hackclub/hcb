# frozen_string_literal: true

# Policies guard their fields when they load (see FieldGuard), so load them all
# up front. Otherwise a field stays unguarded until something loads its policy.
# Eager-loaded environments already load every policy at boot.
if ENV["SECRET_KEY_BASE_DUMMY"].nil? && !Rails.application.config.eager_load
  Rails.application.config.to_prepare do
    Rails.autoloaders.main.eager_load_dir(Rails.root.join("app/policies").to_s)
  end
end
