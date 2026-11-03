# frozen_string_literal: true

module GSuitesHelper
  def example_email_username
    name = current_user&.first_name&.downcase
    name.blank? ? "max" : name
  end
end
