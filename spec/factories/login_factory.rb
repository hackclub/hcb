# frozen_string_literal: true

FactoryBot.define do
  factory(:login) do
    association(:user)
  end
end
