# frozen_string_literal: true

# Extends Doorkeeper's own Application model with the resource-grant
# templates that get copied onto every token minted for it (see
# after_successful_strategy_response in doorkeeper.rb). Kept in its own
# initializer, separate from Doorkeeper.configure, since it's a plain model
# association rather than provider configuration.
Rails.application.config.to_prepare do
  Doorkeeper::Application.class_eval do
    has_many :resource_grant_templates, class_name: "Doorkeeper::Application::ResourceGrantTemplate", foreign_key: :application_id, dependent: :destroy
  end
end
