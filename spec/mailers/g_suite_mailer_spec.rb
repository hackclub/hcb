# frozen_string_literal: true

require "rails_helper"

RSpec.describe GSuiteMailer, type: :mailer do
  let(:g_suite) { create(:g_suite) }

  describe "#notify_of_configuring" do
    let(:mailer) { GSuiteMailer.with(g_suite_id: g_suite.id).notify_of_configuring }

    it "renders to" do
      expect(mailer.to).to eql(g_suite.event.organizer_positions.where(role: :manager).includes(:user).map(&:user).map(&:email))
    end

    it "renders subject" do
      expect(mailer.subject).to eql("[Action Requested] Your Google Workspace for #{g_suite.domain} needs configuration")
    end

    it "includes g suite overview url in body" do
      g_suite_overview_url = File.join(root_url, g_suite.event.slug, "google_workspace")
      expect(mailer.body).to include(g_suite_overview_url)
    end
  end

  describe "#notify_of_verified" do
    let(:mailer) { GSuiteMailer.with(g_suite_id: g_suite.id).notify_of_verified }

    it "renders to" do
      expect(mailer.to).to eql(g_suite.event.organizer_positions.where(role: :manager).includes(:user).map(&:user).map(&:email))
    end

    it "renders subject" do
      expect(mailer.subject).to eql("[Google Workspace Verified] Your Google Workspace for #{g_suite.domain} has been verified")
    end

    it "includes g suite overview url in body" do
      g_suite_overview_url = File.join(root_url, g_suite.event.slug, "google_workspace")
      expect(mailer.body).to include(g_suite_overview_url)
    end
  end
end
