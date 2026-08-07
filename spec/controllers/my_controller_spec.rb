# frozen_string_literal: true

require "rails_helper"

RSpec.describe MyController do
  render_views

  def sign_in_unverified
    user = create(:user, verified: false, full_name: "Unverified Probe")
    user_session = User::Session.create!(
      user:,
      verified: false,
      session_token: SecureRandom.urlsafe_base64,
      expiration_at: 7.days.from_now,
    )
    cookies.encrypted[:session_token] = {
      value: user_session.session_token,
      expires: User::Session::MAX_SESSION_DURATION.from_now,
      httponly: true,
    }
    user_session
  end

  def sign_in_verified(user = create(:user))
    user_session = User::Session.create!(
      user:,
      verified: true,
      session_token: SecureRandom.urlsafe_base64,
      expiration_at: 7.days.from_now,
    )
    cookies.encrypted[:session_token] = {
      value: user_session.session_token,
      expires: User::Session::MAX_SESSION_DURATION.from_now,
      httponly: true,
    }
    user
  end

  describe "GET #cards" do
    it "renders for an unverified user" do
      sign_in_unverified

      get :cards

      expect(response).to have_http_status(:ok)
    end
  end

  describe "GET #reimbursements" do
    it "does not render the authenticated reimbursement-report listing UI for an unverified user" do
      sign_in_unverified

      get :reimbursements

      expect(response.status).to eq(200)
      expect(response.body).to include("Verify your email")
      expect(response.body).not_to include("To review")
    end
  end

  describe "GET #inbox" do
    render_views(false)

    it "sets @locking_count from card_locking_overdue_charges" do
      user = sign_in_verified

      get :inbox

      expect(response).to have_http_status(:ok)
      expect(controller.instance_variable_get(:@locking_count)).to eq(user.card_locking_overdue_charges.count)
    end

    describe "grouping" do
      include_context "card locking charges"

      let(:now) { Time.zone.parse("2026-10-10 12:00:00") }

      before do
        travel_to(now)
        # The deadline UI is gated on the same flag as the card locking callout
        # that explains it; the shared context only enables the enforcement stage
        # that materializes receipt_due_at.
        Flipper.enable(:card_locking_2025_06_09, user)
        sign_in_verified(user)
      end

      def ivar(name) = controller.instance_variable_get(:"@#{name}")

      # The shared context's charges are force captures (HCB-601), which
      # HcbCode.receipt_required excludes — so they never reach the inbox. Build a
      # regular authorized card charge (HCB-600) instead, which needs an
      # "authorization" on the raw transaction's Stripe payload.
      def create_inbox_charge(receipt_due_at:, settled_at: 2.days.ago, amount_cents: -10_00)
        cardholder = user.stripe_cardholder || create(:stripe_cardholder, user:)
        card = (@inbox_card ||= create(:stripe_card, :with_stripe_id, stripe_cardholder: cardholder, event:))

        raw_stripe_transaction = create(
          :raw_stripe_transaction,
          stripe_card: card,
          stripe_transaction: {
            "id"            => "ipi_#{SecureRandom.hex(6)}",
            "card"          => card.stripe_id,
            "type"          => "capture",
            "authorization" => "iauth_#{SecureRandom.hex(6)}",
            "amount"        => -amount_cents,
            "cardholder"    => cardholder.id,
            # network_id matters: rendering a row looks the merchant up, and a nil
            # id trips the missing-merchant reporter rather than rendering an icon.
            "merchant_data" => { "name" => "Test Merchant", "category" => "bakeries", "network_id" => "1234567890" },
          },
          created_at: settled_at, updated_at: settled_at, date_posted: settled_at.to_date
        )
        canonical_transaction = create(
          :canonical_transaction, amount_cents:, memo: "Test Merchant", date: settled_at.to_date,
          created_at: settled_at, updated_at: settled_at, transaction_source: raw_stripe_transaction
        )
        create(:canonical_event_mapping, canonical_transaction:, event:)

        canonical_transaction.local_hcb_code.reload.tap { |hcb_code| hcb_code.update!(receipt_due_at:) }
      end

      # Only cardholders inside the card locking rollout have deadlines at all, so
      # grouping by due date has to earn its place rather than being the default
      # everywhere — otherwise most users get one meaningless "No deadline" pile.
      it "falls back to card grouping when nothing outstanding has a deadline" do
        create_inbox_charge(receipt_due_at: nil)

        get :inbox

        expect(ivar(:count)).to eq(1)
        expect(ivar(:groupable_by_due_date)).to eq(false)
        expect(ivar(:grouping)).to eq("card")
      end

      it "ignores an explicit due date grouping when nothing has a deadline" do
        create_inbox_charge(receipt_due_at: nil)

        get :inbox, params: { group: "due_date" }

        expect(ivar(:grouping)).to eq("card")
      end

      # Card sections are cut from the current page, so on a pile spanning several
      # pages they'd repeat a card's header on every page and split its charges
      # across them. A flat newest-first list is the honest fallback — and it's
      # what this page did before due date grouping existed.
      it "falls back to a flat list when an undated pile spans more than one page" do
        2.times { create_inbox_charge(receipt_due_at: nil) }

        get :inbox, params: { per: 1 }

        expect(ivar(:groupable_by_due_date)).to eq(false)
        expect(ivar(:grouping)).to eq("flat")
        expect(ivar(:cards)).to be_nil
        expect(ivar(:hcb_codes).size).to eq(1)
      end

      it "still groups an undated pile by card when it fits on one page" do
        2.times { create_inbox_charge(receipt_due_at: nil) }

        get :inbox, params: { per: 5 }

        expect(ivar(:grouping)).to eq("card")
      end

      # receipt_due_at is materialized off the enforcement stage flags, which are a
      # separate axis from the flag gating the callout that explains what a
      # deadline is (and gating the lock itself). Surfacing deadlines without it
      # would threaten a consequence that can't happen, unexplained.
      it "keeps deadlines hidden from cardholders outside the card locking flag" do
        Flipper.disable(:card_locking_2025_06_09, user)
        create_inbox_charge(receipt_due_at: 1.day.from_now)

        get :inbox

        expect(ivar(:groupable_by_due_date)).to eq(false)
        expect(ivar(:grouping)).to eq("card")
        expect(ivar(:due_date_groups)).to be_nil
      end

      it "defaults to due date grouping once something has a deadline" do
        create_inbox_charge(receipt_due_at: 1.day.from_now)

        get :inbox

        expect(ivar(:groupable_by_due_date)).to eq(true)
        expect(ivar(:grouping)).to eq("due_date")
        expect(ivar(:due_date_groups).keys).to eq([now.to_date + 1])
      end

      it "honours an explicit card grouping" do
        create_inbox_charge(receipt_due_at: 1.day.from_now)

        get :inbox, params: { group: "card" }

        expect(ivar(:grouping)).to eq("card")
        expect(ivar(:due_date_groups)).to be_nil
      end

      it "falls back to the default rather than trusting an unknown grouping" do
        create_inbox_charge(receipt_due_at: 1.day.from_now)

        get :inbox, params: { group: "../../etc/passwd" }

        expect(ivar(:grouping)).to eq("due_date")
      end

      it "sorts soonest deadline first and pushes deadline-less charges to the end" do
        soon = create_inbox_charge(receipt_due_at: 1.day.from_now)
        later = create_inbox_charge(receipt_due_at: 5.days.from_now)
        undated = create_inbox_charge(receipt_due_at: nil)

        get :inbox

        expect(ivar(:hcb_codes).map(&:id)).to eq([soon.id, later.id, undated.id])
        expect(ivar(:due_date_groups).keys.last).to eq(:none)
      end

      describe "rendering" do
        render_views

        it "renders a section per due date group, with the org on each row" do
          create_inbox_charge(receipt_due_at: 1.day.ago)
          create_inbox_charge(receipt_due_at: 1.day.from_now)

          get :inbox

          expect(response).to have_http_status(:ok)
          expect(response.body).to include("Overdue", "Due tomorrow")
          # Rows from several orgs share one table here, so each needs its org.
          expect(response.body).to include("transaction__event")
          expect(response.body).to include(ERB::Util.html_escape(event.name))
          expect(response.body).to include("By due date", "By card")
        end

        it "omits the grouping tabs when there are no deadlines to group by" do
          create_inbox_charge(receipt_due_at: nil)

          get :inbox

          expect(response).to have_http_status(:ok)
          expect(response.body).not_to include("By due date")
          # The org lives in the card section header instead, not on every row.
          expect(response.body).not_to include("transaction__event")
        end

        it "renders one headerless table when it falls back to a flat list" do
          2.times { create_inbox_charge(receipt_due_at: nil) }

          get :inbox, params: { per: 1 }

          expect(response).to have_http_status(:ok)
          expect(response.body).not_to include("By due date")
          # No section header to carry the org — under card grouping the same
          # pile renders without this — so each row carries its own.
          expect(response.body).to include("transaction__event")
        end
      end

      # The header badge counts the whole group; taking it off the page would
      # under-report any group that spills onto the next one.
      it "counts a group across every page, not just the page being shown" do
        2.times { create_inbox_charge(receipt_due_at: 1.day.ago) }

        get :inbox, params: { per: 1 }

        expect(ivar(:due_date_groups)[:overdue].size).to eq(1)
        expect(ivar(:due_date_group_counts)[:overdue]).to eq(2)
      end
    end
  end

  describe "GET #pay" do
    it "renders even when the user has not received any payments" do
      sign_in_verified

      get :pay

      expect(response).to have_http_status(:ok)
      expect(response.body).to include("No payments yet.")
    end

    it "preserves the selected legal entity in payout settings links" do
      user = sign_in_verified
      legal_entity = create(:legal_entity, :business, name: "Hack Club HQ")
      create(:legal_entity_user, user:, legal_entity:)

      get :pay, params: { legal_entity_id: legal_entity.id }

      expect(response).to redirect_to(my_pay_path)
      expect(session[:legal_entity_id]).to eq(legal_entity.id.to_s)

      get :pay

      expect(response).to have_http_status(:ok)
      expect(response.body).to include(settings_payouts_path(legal_entity_id: legal_entity.id))
    end
  end
end
