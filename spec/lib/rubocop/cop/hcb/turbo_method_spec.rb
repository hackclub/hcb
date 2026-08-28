# frozen_string_literal: true

require "rails_helper"
require "rubocop"
require Rails.root.join("lib/rubocop/cop/hcb/turbo_method")

RSpec.describe RuboCop::Cop::Hcb::TurboMethod do
  let(:config) { RuboCop::Config.new("Hcb/TurboMethod" => { "Enabled" => true }) }
  let(:team) { RuboCop::Cop::Team.new([described_class.new(config)], config) }

  def investigate(source)
    processed_source = RuboCop::ProcessedSource.new(source, RUBY_VERSION.to_f, "app/views/example.html.erb")

    team.investigate(processed_source).offenses
  end

  it "registers an offense for link_to with a UJS method" do
    offenses = investigate(<<~RUBY)
      link_to "Accept invitation", organizer_position_invite_accept_path(@invite), method: :post
    RUBY

    expect(offenses.map(&:message)).to eq(
      ["Use `data: { turbo_method: :post }` instead of `method: :post`. " \
       "Turbo ignores `data-method`, so this link falls back to a GET and 404s."]
    )
  end

  it "registers an offense for pop_icon_to with a UJS method" do
    offenses = investigate(<<~RUBY)
      pop_icon_to "delete", event_tag_path(event, tag.id), method: :delete
    RUBY

    expect(offenses.count).to eq(1)
  end

  it "registers an offense when the link already has a data hash" do
    offenses = investigate(<<~RUBY)
      link_to reimbursement_report_submit_path(report_id: report.id), method: :post, data: { turbo_confirm: "Sure?" }
    RUBY

    expect(offenses.count).to eq(1)
  end

  it "registers an offense for each of the non-GET verbs" do
    offenses = investigate(<<~RUBY)
      link_to "a", path, method: :post
      link_to "b", path, method: :put
      link_to "c", path, method: :patch
      link_to "d", path, method: :delete
    RUBY

    expect(offenses.count).to eq(4)
  end

  it "allows turbo_method" do
    offenses = investigate(<<~RUBY)
      link_to "Accept invitation", organizer_position_invite_accept_path(@invite), data: { turbo_method: :post }
    RUBY

    expect(offenses).to be_empty
  end

  it "allows button_to, which renders a real form" do
    offenses = investigate(<<~RUBY)
      button_to "Cancel donation", cancel_recurring_donation_path(@donation), method: :post
    RUBY

    expect(offenses).to be_empty
  end

  it "allows the form helpers" do
    offenses = investigate(<<~RUBY)
      form_with url: link_receipts_path, method: :post
      form_for model, url: url, method: :post
      form_tag path, method: :patch
    RUBY

    expect(offenses).to be_empty
  end

  it "ignores a `method` key inside a url hash rather than the options" do
    offenses = investigate(<<~RUBY)
      link_to "Show", { controller: "/receipts", action: :show, method: :post }, class: "btn"
    RUBY

    expect(offenses).to be_empty
  end

  it "ignores a plain GET link" do
    offenses = investigate(<<~RUBY)
      link_to "View pending contract", contract_party_path(@invite.contract.party(:signee)), class: "btn bg-accent"
    RUBY

    expect(offenses).to be_empty
  end
end
