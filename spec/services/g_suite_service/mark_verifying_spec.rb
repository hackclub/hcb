# frozen_string_literal: true

require "rails_helper"

RSpec.describe GSuiteService::MarkVerifying, type: :model do
  let(:g_suite) { create(:g_suite, aasm_state: :configuring) }

  let(:service) { GSuiteService::MarkVerifying.new(g_suite_id: g_suite.id) }

  it "changes state" do
    expect(g_suite).not_to be_verifying

    service.run

    expect(g_suite.reload).to be_verifying
  end

end
