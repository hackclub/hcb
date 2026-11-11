# frozen_string_literal: true

FactoryBot.define do
  factory :check_deposit do
    association :event
    association :created_by, factory: :user
    amount_cents { 100_00 }
    front { Rack::Test::UploadedFile.new(Rails.root.join("spec/fixtures/files/receipt.png"), "image/png") }
    back { Rack::Test::UploadedFile.new(Rails.root.join("spec/fixtures/files/receipt.png"), "image/png") }

    trait :submitted do
      column_id { "chkt_#{SecureRandom.hex(8)}" }
      increase_status { :submitted }
    end
  end
end
