# frozen_string_literal: true

require "rails_helper"

RSpec.describe Ledger::Balance::Observer, type: :model do
  include ActiveJob::TestHelper

  let(:event) { create(:event) }
  let(:ledger) { event.ledger }
  let(:user) { create(:user) }

  describe "validations" do
    it "rejects a threshold that is not a positive whole number of cents" do
      expect(build(:ledger_balance_observer, ledger:, user:, amount_cents: 0)).not_to be_valid
      expect(build(:ledger_balance_observer, ledger:, user:, amount_cents: -1)).not_to be_valid
      expect(build(:ledger_balance_observer, ledger:, user:, amount_cents: 1)).to be_valid
    end

    it "rejects a threshold too large for the column instead of overflowing" do
      observer = build(:ledger_balance_observer, ledger:, user:, amount_cents: 10_000_000_00)

      expect(observer).not_to be_valid
      expect(observer.errors[:amount_cents]).to include("must be less than $10,000,000")
    end

    it "allows one observer per user per ledger" do
      create(:ledger_balance_observer, ledger:, user:)

      expect(build(:ledger_balance_observer, ledger:, user:)).not_to be_valid
      expect(build(:ledger_balance_observer, ledger:, user: create(:user))).to be_valid
    end
  end

  describe "#check!" do
    let(:observer) { create(:ledger_balance_observer, ledger:, user:, amount_cents: 50_00) }

    it "emails once per drop below the threshold and re-arms once the balance recovers" do
      expect { observer.check!(balance_cents: 50_00) }.not_to have_enqueued_mail(Ledger::Balance::ObserverMailer, :low_balance)
      expect(observer.notified_at).to be_nil

      expect { observer.check!(balance_cents: 49_99) }.to have_enqueued_mail(Ledger::Balance::ObserverMailer, :low_balance).once
      expect(observer.notified_at).to be_present

      expect { observer.check!(balance_cents: 10_00) }.not_to have_enqueued_mail(Ledger::Balance::ObserverMailer, :low_balance)

      observer.check!(balance_cents: 60_00)
      expect(observer.notified_at).to be_nil

      expect { observer.check!(balance_cents: 40_00) }.to have_enqueued_mail(Ledger::Balance::ObserverMailer, :low_balance).once
    end

    it "re-arms when the threshold changes" do
      observer.check!(balance_cents: 10_00)
      expect(observer.notified_at).to be_present

      observer.update!(amount_cents: 20_00)
      expect(observer.notified_at).to be_nil
    end

    it "checks the balance as soon as the threshold is set or changed, but not on other saves" do
      expect { observer }.to have_enqueued_job(Ledger::Balance::NotifyObserversJob).with(ledger_id: ledger.id)
      expect { observer.update!(amount_cents: 20_00) }.to have_enqueued_job(Ledger::Balance::NotifyObserversJob).with(ledger_id: ledger.id)
      expect { observer.update!(amount_cents: 20_00, notified_at: Time.current) }.not_to have_enqueued_job(Ledger::Balance::NotifyObserversJob)
    end
  end

  describe "ledger hooks" do
    let(:item) { create(:ledger_item, amount_cents: -10_00) }

    it "does nothing for ledgers nobody observes" do
      expect { create(:ledger_mapping, :on_primary, ledger:, ledger_item: item) }.not_to have_enqueued_job(Ledger::Balance::NotifyObserversJob)
    end

    it "checks observers when an item is mapped onto the ledger" do
      create(:ledger_balance_observer, ledger:, user:)

      expect { create(:ledger_mapping, :on_primary, ledger:, ledger_item: item) }
        .to have_enqueued_job(Ledger::Balance::NotifyObserversJob).with(ledger_id: ledger.id).at_least(:once)
    end

    it "checks observers when a mapped item's amount changes" do
      create(:ledger_balance_observer, ledger:, user:)
      create(:ledger_mapping, :on_primary, ledger:, ledger_item: item)
      clear_enqueued_jobs

      expect { item.update!(amount_cents: -20_00) }.to have_enqueued_job(Ledger::Balance::NotifyObserversJob).with(ledger_id: ledger.id).once
      expect { item.update!(memo: "renamed") }.not_to have_enqueued_job(Ledger::Balance::NotifyObserversJob)
    end
  end
end
