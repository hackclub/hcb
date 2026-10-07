# frozen_string_literal: true

FactoryBot.define do
  factory :login_attempt, class: "Login::Attempt" do
    association :login
    factor { :email }
    status { :failed }
    ip_address { "127.0.0.1" }
    user_agent { "fake firefox" }
  end
end
