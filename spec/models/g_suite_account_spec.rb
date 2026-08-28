# frozen_string_literal: true

require "rails_helper"

RSpec.describe GSuiteAccount, type: :model do
  let(:g_suite) { create(:g_suite, domain: "example.com") }
  let(:g_suite_account) { create(:g_suite_account, g_suite:) }

  describe "#unmanage!" do
    let(:gsuite_service) { instance_double(GsuiteService, delete_gsuite_user: true) }

    before do
      allow_any_instance_of(::Partners::Google::GSuite::CreateUserAlias).to receive(:run).and_return(true)
      allow_any_instance_of(::Partners::Google::GSuite::DeleteUserAlias).to receive(:run).and_return(true)
      allow(GsuiteService).to receive(:instance).and_return(gsuite_service)
    end

    context "when confirm does not match address" do
      it "raises ArgumentError and does not destroy the account" do
        expect do
          g_suite_account.unmanage!(confirm: "wrong@example.com")
        end.to raise_error(ArgumentError, /confirm must match address/)

        expect(GSuiteAccount.exists?(g_suite_account.id)).to be true
      end

      it "does not destroy aliases" do
        create(:g_suite_alias, g_suite_account:)
        g_suite_account.reload

        expect do
          g_suite_account.unmanage!(confirm: "wrong@example.com") rescue nil
        end.not_to change(GSuiteAlias, :count)
      end
    end

    context "when confirm matches address" do
      context "with no aliases" do
        it "destroys the account" do
          id = g_suite_account.id

          g_suite_account.unmanage!(confirm: g_suite_account.address)

          expect(GSuiteAccount.exists?(id)).to be false
        end

        it "does not call Google Workspace to delete the user" do
          allow(Rails.env).to receive(:production?).and_return(true)

          g_suite_account.unmanage!(confirm: g_suite_account.address)

          expect(gsuite_service).not_to have_received(:delete_gsuite_user)
        end
      end

      context "with aliases" do
        before do
          create_list(:g_suite_alias, 2, g_suite_account:)
          g_suite_account.reload
        end

        it "destroys the account and its aliases" do
          account_id = g_suite_account.id
          alias_ids = g_suite_account.g_suite_aliases.map(&:id)

          g_suite_account.unmanage!(confirm: g_suite_account.address)

          expect(GSuiteAccount.exists?(account_id)).to be false
          expect(GSuiteAlias.where(id: alias_ids)).to be_empty
        end

        it "does not call Google Workspace to delete any alias" do
          expect_any_instance_of(::Partners::Google::GSuite::DeleteUserAlias).not_to receive(:run)

          g_suite_account.unmanage!(confirm: g_suite_account.address)
        end

        it "rolls back the destroy when an alias destroy fails" do
          allow_any_instance_of(GSuiteAlias).to receive(:destroy!).and_raise(ActiveRecord::RecordNotDestroyed.new("boom"))

          expect do
            g_suite_account.unmanage!(confirm: g_suite_account.address)
          end.to raise_error(ActiveRecord::RecordNotDestroyed)

          expect(GSuiteAccount.exists?(g_suite_account.id)).to be true
          expect(g_suite_account.g_suite_aliases.reload.count).to eq(2)
        end

        it "does not call Google Workspace on the rollback path" do
          allow(Rails.env).to receive(:production?).and_return(true)
          allow_any_instance_of(GSuiteAlias).to receive(:destroy!).and_raise(ActiveRecord::RecordNotDestroyed.new("boom"))
          expect_any_instance_of(::Partners::Google::GSuite::DeleteUserAlias).not_to receive(:run)

          expect do
            g_suite_account.unmanage!(confirm: g_suite_account.address)
          end.to raise_error(ActiveRecord::RecordNotDestroyed)

          expect(gsuite_service).not_to have_received(:delete_gsuite_user)
        end
      end

      it "logs a structured disconnect line before destroying" do
        create_list(:g_suite_alias, 2, g_suite_account:)
        g_suite_account.reload

        expect(Rails.logger).to receive(:info).with(
          a_string_including(
            "[GSuiteAccount#unmanage!]",
            "unmanaging",
            "id=#{g_suite_account.id}",
            "address=#{g_suite_account.address}",
            "g_suite_id=#{g_suite_account.g_suite_id}",
            "aliases=2"
          )
        )

        g_suite_account.unmanage!(confirm: g_suite_account.address)
      end
    end
  end

  describe "#sync_delete_to_gsuite (callback)" do
    before do
      allow(Rails.env).to receive(:production?).and_return(true)
    end

    it "calls GsuiteService.delete_gsuite_user on a normal destroy" do
      gsuite_service = instance_double(GsuiteService, delete_gsuite_user: true)
      allow(GsuiteService).to receive(:instance).and_return(gsuite_service)

      g_suite_account.destroy!

      expect(gsuite_service).to have_received(:delete_gsuite_user).with(g_suite_account.address)
    end

    it "does not call GsuiteService when skip_gsuite_sync is true" do
      gsuite_service = instance_double(GsuiteService, delete_gsuite_user: true)
      allow(GsuiteService).to receive(:instance).and_return(gsuite_service)

      g_suite_account.skip_gsuite_sync = true
      g_suite_account.destroy!

      expect(gsuite_service).not_to have_received(:delete_gsuite_user)
    end
  end
end
