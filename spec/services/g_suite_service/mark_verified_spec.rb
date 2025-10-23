# frozen_string_literal: true

require "rails_helper"

RSpec.describe GSuiteService::MarkVerified, type: :model do
  let(:g_suite) { create(:g_suite, aasm_state: :verifying) }

  let(:service) { GSuiteService::MarkVerified.new(g_suite_id: g_suite.id) }

  context "when verified_on_google is true" do
    before do
      allow(service).to receive(:verified_on_google?).and_return(true)
    end

    it "changes state" do
      expect(g_suite).not_to be_verified

      service.run

      expect(g_suite.reload).to be_verified
    end

    it "does not send an email" do
      service.run

      mail = ActionMailer::Base.deliveries.last

      expect(mail).to eql(nil)
    end

    context "when created by exists" do
      let(:user) { create(:user) }

      before do
        g_suite.created_by = user
        g_suite.save!
      end

      it "sends an email" do
        service.run

        mail = ActionMailer::Base.deliveries.last

        expect(mail.to).to eql(g_suite.event.organizer_positions.where(role: :manager).includes(:user).map(&:user).map(&:email))
        expect(mail.subject).to include(g_suite.domain)
      end
    end
  end

  context "when verified_on_google is false" do
    before do
      allow(service).to receive(:verified_on_google?).and_return(false)
    end

    it "does not change state" do
      service.run

      expect(g_suite.reload).to_not be_verified
    end

    it "does not send a mailer" do
      service.run
    end

    context "when created by exists" do
      let(:user) { create(:user) }

      before do
        g_suite.created_by = user
        g_suite.save!
      end

      it "does not send an email" do
        service.run

        mail = ActionMailer::Base.deliveries.last

        expect(mail).to eql(nil)
      end

      it "does not change state" do
        expect(g_suite).not_to be_verified

        service.run

        expect(g_suite.reload).not_to be_verified
      end
    end
  end

  context "when network or other error occurs" do
    before do
      allow(service).to receive(:verified_on_google?).and_raise(ArgumentError)
    end

    it "does not change state" do
      expect do
        service.run
      end.to raise_error(ArgumentError)

      expect(g_suite.reload).to_not be_verified
    end
  end
end
