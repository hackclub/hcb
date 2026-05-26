# frozen_string_literal: true

require "rails_helper"

RSpec.describe GSuiteMailer, type: :mailer do
  let(:g_suite) { create(:g_suite) }

  # `ApplicationMailer#mail` subtracts `ApplicationMailer.earmuffed_recipients`
  # from the message's `to`. That list is built by looking up users by the
  # production public_ids in `EARMUFFED_USER_IDS` — and `usr_b9YtZb`
  # (Zach) decodes to `User#id == 1`. In a fresh CI shard's DB the first
  # user created lands at id 1, so if that happens to be one of this
  # spec's managers, the production filter silently strips their email
  # out of `mailer.to`. Stub it here so the test is unaffected by who
  # happens to hold id 1.
  before { allow(ApplicationMailer).to receive(:earmuffed_recipients).and_return([]) }

  describe "#notify_of_configuring" do
    let(:mailer) { GSuiteMailer.with(g_suite_id: g_suite.id).notify_of_configuring }

    it "renders to" do
      expect(mailer.to).to match_array(g_suite.event.organizer_positions.where(role: :manager).includes(:user).map(&:user).map(&:email))
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
