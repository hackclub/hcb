# frozen_string_literal: true

require "factory_bot"

RSpec.configure do |config|
  config.include FactoryBot::Syntax::Methods
end

FactoryBot::SyntaxRunner.include RSpec::Mocks::ExampleMethods
