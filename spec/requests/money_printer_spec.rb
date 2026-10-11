# frozen_string_literal: true

require "rails_helper"

RSpec.describe "Money Printer dashboard", type: :request do
  let(:stats) do
    {
      net_delta_cents: 123_456,
      sum_old_cents: 1_000_000,
      sum_new_cents: 1_123_456,
      total_orgs: 100,
      matching_orgs: 97,
      leaderboard: [
        { event_id: 1, public_id: "org_abc123", slug: "cool-org", name: "Cool Org", delta_cents: 50_000 }
      ],
      computed_at: Time.current
    }
  end

  context "when the flag is disabled" do
    it "returns 404" do
      get money_printer_path
      expect(response).to have_http_status(:not_found)
    end
  end

  context "when the flag is enabled" do
    before { Flipper.enable(MoneyPrinterController::FLAG) }
    after { Flipper.disable(MoneyPrinterController::FLAG) }

    it "renders the dashboard for a signed-out visitor when stats are cached" do
      allow(Rails.cache).to receive(:read).with(MoneyPrinterStatsJob::CACHE_KEY).and_return(stats)

      get money_printer_path

      expect(response).to have_http_status(:ok)
      expect(response.body).to include('data-controller="money-printer"')
    end

    it "shows the warming-up state and enqueues the job on a cold cache" do
      allow(Rails.cache).to receive(:read).with(MoneyPrinterStatsJob::CACHE_KEY).and_return(nil)
      expect(MoneyPrinterStatsJob).to receive(:perform_later)

      get money_printer_path

      expect(response).to have_http_status(:ok)
      expect(response.body).to include("Warming up the printer")
    end

    it "redacts organization identities (no name, slug, or public ID) for non-admins" do
      allow(Rails.cache).to receive(:read).with(MoneyPrinterStatsJob::CACHE_KEY).and_return(stats)

      get money_printer_path

      expect(response.body).to include("REDACTED")
      expect(response.body).not_to include("Cool Org")
      expect(response.body).not_to include("cool-org")
      expect(response.body).not_to include("org_abc123")
    end

    it "renders the comical caption and accuracy for a printing net delta" do
      allow(Rails.cache).to receive(:read).with(MoneyPrinterStatsJob::CACHE_KEY).and_return(stats)

      get money_printer_path

      expect(response.body).to include("Go brrr")
      expect(response.body).to include("97.0%")
    end

    it "shows organization names to auditors" do
      auditor = create(:user, :make_auditor)
      session = create(:user_session, user: auditor, verified: true, expiration_at: 1.hour.from_now)
      allow_any_instance_of(SessionsHelper).to receive(:find_current_session).and_return(session)
      allow(Rails.cache).to receive(:read).with(MoneyPrinterStatsJob::CACHE_KEY).and_return(stats)

      get money_printer_path

      expect(response.body).to include("Cool Org")
    end
  end
end
