# frozen_string_literal: true

Rails.application.config.to_prepare do
  Blazer::Check.class_eval do
    after_initialize do
      self.emails = ApplicationMailer::ENGINEERING_EMAIL if new_record? && emails.blank?
    end
  end
end
