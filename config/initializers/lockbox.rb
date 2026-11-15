# frozen_string_literal: true

# https://github.com/ankane/lockbox

master_key = Credentials.fetch(:LOCKBOX)

if master_key.blank? && Rails.env.test?
  master_key = Lockbox.generate_key
  warn("⚠️ Using temporary Lockbox master key: #{master_key.inspect}")
end

Lockbox.master_key = master_key
