# frozen_string_literal: true

# https://guides.rubyonrails.org/autoloading_and_reloading_constants.html#option-3-preload-a-regular-directory
if ENV["SECRET_KEY_BASE_DUMMY"].nil? && !Rails.application.config.eager_load
  Rails.application.config.to_prepare do
    Rails.autoloaders.main.eager_load_dir(Rails.root.join("app/models/metric").to_s)
    Rails.autoloaders.main.eager_load_dir(Rails.root.join("app/models/event/plan").to_s)
  end
end
