# frozen_string_literal: true

require "rails_helper"

RSpec.describe GSuiteAccountService::Create, type: :model do
  let(:g_suite) { create(:g_suite, domain: "event.example.com") }
  let(:current_user) { create(:user) }
  let(:event) { create(:event) }

  let(:backup_email) { "backup@mailinator.com" }
  let(:address) { "address" }
  let(:first_name) { "First" }
  let(:last_name) { "Last" }

  let(:remote_org_unit) do
    ou_name = "##{event.id} G##{g_suite.id}"
    double("remoteOrgUnit", name: ou_name, org_unit_id: "id:1234", org_unit_path: "/Events/#{ou_name}")
  end

  let(:service) do
    GSuiteAccountService::Create.new(
      g_suite:,
      current_user:,

      backup_email:,
      address:,
      first_name:,
      last_name:
    )
  end

  before do
    allow_any_instance_of(::Partners::Google::GSuite::OrgUnit).to receive(:run).and_return(remote_org_unit)
    allow_any_instance_of(::Partners::Google::GSuite::CreateUser).to receive(:run).and_return(remote_org_unit)
  end

  it "creates g suite account" do
    expect do
      service.run
    end.to change(GSuiteAccount, :count).by(1)
  end

  it "sends 1 mailer" do
    g_suite_account = nil

    perform_enqueued_jobs do
      g_suite_account = service.run
    end

    mail = ActionMailer::Base.deliveries.last

    expect(mail.to).to eql(["backup@mailinator.com"])
    expect(mail.subject).to include("Your Google Workspace account via HCB is ready")
    expect(mail.body.encoded).to include("address@event.example.com")
    expect(mail.body.encoded).to include(g_suite_account.initial_password)
  end

  context "when remote org unit does not exist" do
    before do
      allow_any_instance_of(::Partners::Google::GSuite::OrgUnit).to receive(:run).and_return(nil)
      allow_any_instance_of(::Partners::Google::GSuite::CreateOrgUnit).to receive(:run).and_return(remote_org_unit)
    end

    it "creates the remote org unit and creates the g suite account" do
      expect do
        service.run
      end.to change(GSuiteAccount, :count).by(1)
    end

    it "assigns remote_org_unit_id" do
      expect do
        service.run
      end.to change(g_suite.reload, :remote_org_unit_id).to("id:1234")
    end

    it "assigns remote_org_unit_path" do
      expect do
        service.run
      end.to change(g_suite.reload, :remote_org_unit_path).to("/Events/##{event.id} G##{g_suite.id}")
    end
  end

  context "when remote create user fails" do
    before do
      allow_any_instance_of(::Partners::Google::GSuite::CreateUser).to receive(:run).and_raise(ArgumentError)
    end

    it "does not create g suite account" do
      expect do
        service.run rescue nil
      end.not_to change(GSuiteAccount, :count)
    end

    it "raises an error" do
      expect do
        service.run
      end.to raise_error(ArgumentError)
    end
  end

  context "when g suite account quota is reached" do
    before do
      g_suite.update!(max_accounts: 1)
      GSuiteAccount.create!(
        g_suite:,
        creator: current_user,
        backup_email: "a@example.com",
        address: "asl@event.example.com",
        first_name: "Test",
        last_name: "User",
        accepted_at: DateTime.now
      )
    end

    it "does not create an account" do
      expect do
        service.run rescue nil
      end.not_to change(GSuiteAccount, :count)
    end

    it "raises an error" do
      expect do
        service.run
      end.to raise_error(ActiveRecord::RecordInvalid)
    end
  end

  describe "private" do
    describe "#full_email_address" do
      it "builds" do
        result = service.send(:full_email_address)

        expect(result).to eql("address@event.example.com")
      end
    end
  end
end
