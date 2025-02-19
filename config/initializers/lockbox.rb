# frozen_string_literal: true

# https://github.com/ankane/lockbox

Lockbox.master_key = Rails.application.credentials.dig(:lockbox, :master_key)
