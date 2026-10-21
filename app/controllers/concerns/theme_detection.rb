# frozen_string_literal: true

module ThemeDetection
  extend ActiveSupport::Concern

  included do
    before_action :set_theme
  end

  private

  def set_theme
    @is_dark = !!@dark || cookies[:theme] == "dark" || (cookies[:theme] == "system" && cookies[:system_preference] == "dark")
  end
end
