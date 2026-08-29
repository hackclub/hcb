# frozen_string_literal: true

require "rails_helper"

RSpec.describe GSuiteAlias, type: :model do
  let(:g_suite_account) { create(:g_suite_account) }

  before do
    allow_any_instance_of(::Partners::Google::GSuite::CreateUserAlias).to receive(:run).and_return(true)
  end

  describe "before_destroy (sync to Google Workspace)" do
    let(:g_suite_alias) { create(:g_suite_alias, g_suite_account:) }

    it "calls Partners::Google::GSuite::DeleteUserAlias on a normal destroy" do
      expect_any_instance_of(::Partners::Google::GSuite::DeleteUserAlias).to receive(:run).and_return(true)

      g_suite_alias.destroy!
    end

    it "does not call Partners::Google::GSuite::DeleteUserAlias when skip_gsuite_sync is true" do
      expect_any_instance_of(::Partners::Google::GSuite::DeleteUserAlias).not_to receive(:run)

      g_suite_alias.skip_gsuite_sync = true
      g_suite_alias.destroy!
    end
  end
end
