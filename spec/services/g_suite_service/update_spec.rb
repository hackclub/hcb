# frozen_string_literal: true

require "rails_helper"

RSpec.describe GSuiteService::Update, type: :model do
  let(:g_suite) { create(:g_suite, verification_key: "original_key") }

  context "when nothing changes" do
    let(:service) {
      GSuiteService::Update.new(
        g_suite_id: g_suite.id,
        domain: g_suite.domain,
        verification_key: g_suite.verification_key
      )
    }

    it "sends 0 mailers" do
      service.run

      count = ActionMailer::Base.deliveries.count

      expect(count).to eql(0)
    end
  end

  context "when verification key is changed" do
    let(:service) {
      GSuiteService::Update.new(
        g_suite_id: g_suite.id,
        domain: g_suite.domain,
        verification_key: "new_key"
      )
    }

    it "puts it into configuring state" do
      original_aasm_state = g_suite.aasm_state

      g_suite_result = service.run

      expect(g_suite_result.aasm_state).to_not eql(original_aasm_state)
      expect(g_suite_result.aasm_state).to eql("configuring")
    end

    it "updates g suite" do
      original_verification_key = g_suite.verification_key

      g_suite_result = service.run

      expect(g_suite_result.verification_key).not_to eql(original_verification_key)
    end

    it "does not send a mailer" do
      expect do
        service.run
      end.to_not change(ActionMailer::Base.deliveries, :count)
    end

    context "when g_suite has created_by" do
      let(:user) { create(:user) }

      before do
        g_suite.created_by = user
        g_suite.save!
      end

      it "does send 1 mailer" do
        expect do
          service.run
        end.to change(ActionMailer::Base.deliveries, :count).by(1)

        mail = ActionMailer::Base.deliveries.last

        expect(mail.to).to eql(g_suite.event.organizer_positions.where(role: :manager).includes(:user).map(&:user).map(&:email))
        expect(mail.subject).to include(g_suite.domain)
      end
    end
  end

  context "when domain is changed" do
    let(:updated_domain) { "newdomain.com" }
    let(:service) {
      GSuiteService::Update.new(
        g_suite_id: g_suite.id,
        domain: updated_domain,
        verification_key: g_suite.verification_key
      )
    }

    before do
      g_suite.mark_configuring!
    end

    it "changes domain and makes call to delete domain and create domain" do
      original_domain = g_suite.domain

      expect_any_instance_of(::Partners::Google::GSuite::DeleteDomain).to receive(:run).and_return(true)
      expect_any_instance_of(::Partners::Google::GSuite::CreateDomain).to receive(:run).and_return(true)

      g_suite_result = service.run

      expect(g_suite_result.domain).not_to eql(original_domain)
    end

    it "sends 1 mailer" do
      service.run

      mail = ActionMailer::Base.deliveries.last

      expect(mail.to).to eql(["hcb@hackclub.com"])
      expect(mail.subject).to include(updated_domain)
    end

    it "changes status back to creating and sets verification key to nil (even though it was attempted to be set)" do
      original_aasm_state = g_suite.aasm_state
      original_verification_key = g_suite.verification_key

      g_suite_result = service.run

      expect(g_suite_result.aasm_state).not_to eql(original_aasm_state)
      expect(g_suite_result.aasm_state).to eql("creating")
      expect(g_suite_result.verification_key).not_to eql(original_verification_key)
      expect(g_suite_result.verification_key).to eql(nil)
    end
  end
end
