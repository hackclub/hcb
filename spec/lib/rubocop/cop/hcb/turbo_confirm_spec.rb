# frozen_string_literal: true

require "rails_helper"
require "rubocop"
require Rails.root.join("lib/rubocop/cop/hcb/turbo_confirm")

RSpec.describe RuboCop::Cop::Hcb::TurboConfirm do
  let(:config) { RuboCop::Config.new("Hcb/TurboConfirm" => { "Enabled" => true }) }
  let(:team) { RuboCop::Cop::Team.new([described_class.new(config)], config) }

  def investigate(source)
    processed_source = RuboCop::ProcessedSource.new(source, RUBY_VERSION.to_f, "app/views/example.html.erb")

    team.investigate(processed_source).offenses
  end

  it "registers an offense for data confirm" do
    offenses = investigate(<<~RUBY)
      link_to "Cancel donation", cancel_path, data: { confirm: "Are you sure?" }
    RUBY

    expect(offenses.map(&:message)).to eq(
      ["Use `data: { turbo_confirm: ... }` instead of `data: { confirm: ... }`."]
    )
  end

  it "allows turbo_confirm" do
    offenses = investigate(<<~RUBY)
      link_to "Cancel donation", cancel_path, data: { turbo_confirm: "Are you sure?" }
    RUBY

    expect(offenses).to be_empty
  end
end
