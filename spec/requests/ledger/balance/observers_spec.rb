# frozen_string_literal: true

require "rails_helper"

RSpec.describe "Ledger::Balance::ObserversController", type: :request do
  let(:event) { create(:event) }
  let(:ledger) { event.ledger }
  let(:user) { create(:user) }

  def sign_in_as(user)
    allow_any_instance_of(SessionsHelper).to receive(:find_current_session).and_return(create(:user_session, user:))
  end

  describe "POST /ledgers/:ledger_id/balance_observer" do
    it "requires access to the ledger" do
      sign_in_as(user)

      expect { post ledger_balance_observer_path(ledger), params: { amount: "50.00" } }.not_to change(Ledger::Balance::Observer, :count)
      expect(flash[:error]).to eq("You are not authorized to perform this action.")
    end

    it "redirects signed-out users to log in" do
      post ledger_balance_observer_path(ledger), params: { amount: "50.00" }

      expect(response).to redirect_to(auth_users_path(return_to: ledger_balance_observer_url(ledger), require_reload: true))
    end

    context "as a reader" do
      before do
        create(:organizer_position, user:, event:, role: :reader)
        sign_in_as(user)
      end

      it "creates, then updates, the signed-in user's own alert" do
        post ledger_balance_observer_path(ledger), params: { amount: "50.00" }
        observer = Ledger::Balance::Observer.find_by!(ledger:, user:)
        expect(observer.amount_cents).to eq(50_00)

        expect { post ledger_balance_observer_path(ledger), params: { amount: "1,250.50" } }.not_to change(Ledger::Balance::Observer, :count)
        expect(observer.reload.amount_cents).to eq(1_250_50)
      end

      it "rejects a non-positive amount" do
        post ledger_balance_observer_path(ledger), params: { amount: "0" }

        expect(Ledger::Balance::Observer.count).to eq(0)
        expect(flash[:error]).to eq("Amount cents must be greater than 0")
      end
    end
  end

  describe "DELETE /ledgers/:ledger_id/balance_observer" do
    let!(:observer) { create(:ledger_balance_observer, ledger:, user:) }

    it "removes only the signed-in user's own alert" do
      manager = create(:user)
      create(:organizer_position, user: manager, event:, role: :manager)
      sign_in_as(manager)

      delete ledger_balance_observer_path(ledger)

      expect(response).to have_http_status(:not_found)
      expect(observer.reload).to be_persisted
    end

    it "removes the alert for its owner" do
      sign_in_as(user)

      delete ledger_balance_observer_path(ledger)

      expect(Ledger::Balance::Observer.exists?(observer.id)).to eq(false)
      expect(flash[:success]).to eq("Balance alert removed.")
    end
  end
end
