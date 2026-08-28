# frozen_string_literal: true

require "rails_helper"

RSpec.describe CardGrantsController do
  include SessionSupport
  render_views

  describe "read-only grant settings" do
    it "allows members to view, but not edit, grant settings" do
      member = create(:user)
      event = create(:event, :with_positive_balance, plan_type: Event::Plan::HackClubAffiliate)
      create(:organizer_position, user: member, event:, role: :member)
      card_grant = create(:card_grant, event:)
      create_session(member, verified: true)

      get(:edit_purpose, params: { event_id: event.friendly_id, id: card_grant.hashid })

      expect(response).to have_http_status(:ok)
      expect(response.parsed_body.at_css("[name='card_grant[purpose]']")["disabled"]).to eq("disabled")
      expect(response.parsed_body.at_css("[value='Save']")["disabled"]).to eq("disabled")

      original_purpose = card_grant.purpose
      patch(:update, params: {
              id: card_grant.hashid,
              card_grant: { purpose: "Updated purpose" }
            })

      expect(flash[:error]).to match(/not authorized/i)
      expect(card_grant.reload.purpose).to eq(original_purpose)
    end
  end

  describe "#new" do
    it "renders successfully" do
      user = create(:user)
      event = create(:event)
      create(:organizer_position, user:, event:)
      create_session(user, verified: true)

      expect(event.card_grant_setting).to be_nil

      get(:new, params: { event_id: event.friendly_id })

      expect(response).to have_http_status(:ok)
      expect(event.reload.card_grant_setting).to be_present
    end

    it "uses the email param to pre-fill the email field" do
      user = create(:user)
      event = create(:event)
      create(:organizer_position, user:, event:)
      create_session(user, verified: true)

      expect(event.card_grant_setting).to be_nil

      get(:new, params: { event_id: event.friendly_id, email: "orpheus@hackclub.com" })

      expect(response).to have_http_status(:ok)
      expect(event.reload.card_grant_setting).to be_present
      input = response.parsed_body.css("[name='card_grant[email]']").sole
      expect(input.get_attribute("value")).to eq("orpheus@hackclub.com")
    end
  end

  describe "#create" do
    def card_grant_params
      {
        amount_cents: "123.45",
        email: "recipient@example.com",
        invite_message: "this is a really cool card grant",
        purpose: "Raffle prize",
        one_time_use: "true",
        pre_authorization_required: "true",
        instructions: "Here's a card grant for your raffle prize"
      }
    end

    it "creates a card grant" do
      user = create(:user)
      event = create(:event, :with_positive_balance, plan_type: Event::Plan::HackClubAffiliate)
      create(:card_grant_setting, event:)
      create(:organizer_position, user:, event:)
      create_session(user, verified: true)

      post(
        :create,
        params: {
          event_id: event.friendly_id,
          card_grant: card_grant_params,
        }
      )

      expect(response).to redirect_to(event_transfers_path(event))
      card_grant = event.card_grants.sole
      expect(card_grant.amount_cents).to eq(123_45)
      expect(card_grant.email).to eq("recipient@example.com")
      expect(card_grant.purpose).to eq("Raffle prize")
      expect(card_grant.one_time_use).to eq(true)
      expect(card_grant.pre_authorization_required).to eq(true)
      expect(card_grant.instructions).to eq("Here's a card grant for your raffle prize")
    end

    it "handles validation errors" do
      user = create(:user)
      event = create(:event, :with_positive_balance, plan_type: Event::Plan::HackClubAffiliate)
      create(:card_grant_setting, event:)
      create(:organizer_position, user:, event:)
      create_session(user, verified: true)

      post(
        :create,
        params: {
          event_id: event.friendly_id,
          card_grant: {
            **card_grant_params,
            purpose: "This is a very long purpose that should exceed the 30 character limit"
          }
        }
      )

      expect(event.card_grants).to be_empty
      expect(response).to have_http_status(:unprocessable_content)
      expect(flash[:error]).to eq("Purpose is too long (maximum is 30 characters)")
    end

    it "handles downstream errors" do
      user = create(:user)
      event = create(:event, :with_positive_balance, plan_type: Event::Plan::HackClubAffiliate)
      create(:card_grant_setting, event:)
      create(:organizer_position, user:, event:)
      create_session(user, verified: true)

      post(
        :create,
        params: {
          event_id: event.friendly_id,
          card_grant: {
            **card_grant_params,
            amount_cents: "12345.67",
          }
        }
      )

      expect(event.card_grants).to be_empty
      expect(response).to have_http_status(:unprocessable_content)
      expect(flash[:error]).to eq("You don't have enough money to make this disbursement.")
    end
  end

  describe "topup" do
    it "tops up a card grant" do
      user = create(:user)
      event = create(:event, :with_positive_balance, plan_type: Event::Plan::HackClubAffiliate)
      create(:organizer_position, user:, event:)
      create_session(user, verified: true)

      card_grant = create(
        :card_grant,
        event:,
        sent_by: user,
        amount_cents: 12_34
      )

      post(
        :topup,
        params: {
          event_id: event.friendly_id,
          id: card_grant.hashid,
          amount: "56.78"
        }
      )

      expect(flash[:success]).to eq("Successfully topped up grant.")
      expect(response).to redirect_to(card_grant_path(card_grant))

      expect(card_grant.reload.balance).to eq(Money.new(69_12, :usd))

      disbursement = event.disbursements.last
      expect(disbursement.amount).to eq(56_78)
      expect(disbursement.source_event).to eq(event)
      expect(disbursement.event).to eq(event)
      expect(disbursement.source_subledger_id).to be_nil
      expect(disbursement.destination_subledger_id).to eq(card_grant.subledger_id)
      expect(disbursement.requested_by_id).to eq(user.id)
    end

    it "handles downstream errors" do
      user = create(:user)
      event = create(:event, :with_positive_balance, plan_type: Event::Plan::HackClubAffiliate)
      create(:organizer_position, user:, event:)
      create_session(user, verified: true)

      card_grant = create(
        :card_grant,
        event:,
        sent_by: user,
        amount_cents: 12_34
      )

      expect do
        post(
          :topup,
          params: {
            event_id: event.friendly_id,
            id: card_grant.hashid,
            amount: "12345.67"
          }
        )
      end.not_to change(event.disbursements, :count)

      expect(flash[:error]).to eq("You don't have enough money to make this disbursement.")
      expect(response).to redirect_to(card_grant_path(card_grant))

      expect(card_grant.reload.balance).to eq(Money.new(12_34, :usd))
    end
  end

  describe "#accept_as_reimbursement" do
    def setup_grant(*traits, **overrides)
      event = create(:event, :with_positive_balance, plan_type: Event::Plan::HackClubAffiliate)
      create(:card_grant_setting, event:)
      create(
        :card_grant,
        :pending_invite,
        *traits,
        **{ event:, amount_cents: 10_00, allow_reimbursement_report: true }.merge(overrides)
      )
    end

    it "opens a reimbursement report and redirects to it" do
      card_grant = setup_grant
      allow(User).to receive(:system_user).and_return(create(:user, email: User::SYSTEM_USER_EMAIL))
      create_session(card_grant.user, verified: true)

      expect do
        post(:accept_as_reimbursement, params: { id: card_grant.hashid })
      end.to change(Reimbursement::Report, :count).by(1)

      report = card_grant.reload.reimbursement_report
      expect(report).to be_present
      expect(response).to redirect_to(report)
      expect(flash[:success]).to eq("Successfully opened a reimbursement report for your grant.")
    end

    it "reuses an existing reimbursement report instead of creating a new one" do
      card_grant = setup_grant
      existing = create(:reimbursement_report, event: card_grant.event, user: card_grant.user, card_grant:)
      create_session(card_grant.user, verified: true)

      expect do
        post(:accept_as_reimbursement, params: { id: card_grant.hashid })
      end.not_to change(Reimbursement::Report, :count)

      expect(response).to redirect_to(existing)
    end

    it "does not authorize acceptance when reimbursement reports are disabled" do
      card_grant = setup_grant(allow_stripe_card: true, allow_reimbursement_report: false)
      create_session(card_grant.user, verified: true)

      expect do
        post(:accept_as_reimbursement, params: { id: card_grant.hashid })
      end.not_to change(Reimbursement::Report, :count)

      expect(flash[:error]).to eq("You are not authorized to perform this action.")
    end

    it "does not authorize acceptance once a virtual card has been activated" do
      # Converting an activated grant is `#convert_to_reimbursement_report`,
      # which is gated by the event's `reimbursement_conversions_enabled` flag.
      event = create(:event, :with_positive_balance, plan_type: Event::Plan::HackClubAffiliate)
      create(:card_grant_setting, event:, reimbursement_conversions_enabled: false)
      card_grant = create(:card_grant, event:, amount_cents: 10_00, allow_reimbursement_report: true)
      create_session(card_grant.user, verified: true)

      expect do
        post(:accept_as_reimbursement, params: { id: card_grant.hashid })
      end.not_to change(Reimbursement::Report, :count)

      expect(flash[:error]).to eq("You are not authorized to perform this action.")
    end

    it "does not authorize acceptance while pre-authorization is outstanding" do
      card_grant = setup_grant(pre_authorization_required: true)
      expect(card_grant.pre_authorization).to be_draft
      create_session(card_grant.user, verified: true)

      expect do
        post(:accept_as_reimbursement, params: { id: card_grant.hashid })
      end.not_to change(Reimbursement::Report, :count)

      expect(flash[:error]).to eq("You are not authorized to perform this action.")
    end
  end

  describe "#show" do
    def render_show(**flags)
      event = create(:event, :with_positive_balance, plan_type: Event::Plan::HackClubAffiliate)
      create(:card_grant_setting, event:)
      card_grant = create(:card_grant, :pending_invite, event:, amount_cents: 10_00, instructions: "Buy **pizza**", purpose: "Pizza", **flags)
      create_session(card_grant.user, verified: true)
      get(:show, params: { id: card_grant.hashid })
      expect(response).to have_http_status(:ok)
      response.parsed_body
    end

    it "renders the card-only invitation" do
      body = render_show(allow_stripe_card: true, allow_reimbursement_report: false)
      expect(body.css("form[action*='activate']").length).to eq(1)
      expect(body.css("input[name='terms'][required]").length).to eq(1)
      expect(body.to_s).not_to include("accept_as_reimbursement")
    end

    it "renders the reimbursement-only invitation" do
      body = render_show(allow_stripe_card: false, allow_reimbursement_report: true)
      expect(body.css("form[action*='accept_as_reimbursement']").length).to eq(1)
      expect(body.css("input[name='purpose'][required]").length).to eq(1)
      expect(body.css("input[name='policy'][required]").length).to eq(1)
      expect(body.css("input[name='terms']").length).to eq(0)
    end

    it "renders both options in one form with a formaction override" do
      body = render_show(allow_stripe_card: true, allow_reimbursement_report: true)
      form = body.css("form[action*='accept_as_reimbursement']").sole
      expect(form.css("input[name='purpose'][required]").length).to eq(1)
      expect(form.css("input[name='policy'][required]").length).to eq(1)
      # Card Issuing Terms are JS-gated, not `required`.
      expect(form.css("input[type='checkbox'][name='terms'][required]").length).to eq(0)
      submits = form.css("input[type='submit']")
      expect(submits.map { |s| s.get_attribute("value") }).to eq(["Get a virtual card", "Open a reimbursement"])
      expect(submits.first.get_attribute("formaction")).to include("/activate")
      # Neither button is disabled in HTML: the page works without JavaScript.
      expect(submits.map { |s| s.get_attribute("disabled") }).to eq([nil, nil])
      expect(body.to_s).to include("Buy <strong>pizza</strong>")
    end
  end
end
