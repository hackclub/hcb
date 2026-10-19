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

    it "uses the purpose and instructions params to pre-fill the form" do
      user = create(:user)
      event = create(:event)
      create(:organizer_position, user:, event:)
      create_session(user, verified: true)

      get(:new, params: { event_id: event.friendly_id, purpose: "iPad Grant", instructions: "Please only buy an iPad." })

      expect(response).to have_http_status(:ok)
      purpose = response.parsed_body.css("[name='card_grant[purpose]']").sole
      expect(purpose.get_attribute("value")).to eq("iPad Grant")
      instructions = response.parsed_body.css("[name='card_grant[instructions]']").sole
      expect(instructions.text.strip).to eq("Please only buy an iPad.")
    end

    it "pre-fills the form from a template" do
      user = create(:user)
      event = create(:event, plan_type: Event::Plan::HackClubAffiliate)
      create(:organizer_position, user:, event:)
      create_session(user, verified: true)
      template = create(
        :card_grant_template,
        event:,
        name: "Pizza",
        amount_cents: 42_50,
        purpose: "Pizza night",
        invite_message: "Enjoy!",
        one_time_use: true,
        merchant_lock: ["123", "456"],
        category_lock: ["fast_food_restaurants"],
        keyword_lock: "\\APizza",
        banned_merchants: ["789"],
        banned_categories: ["betting_casino_gambling"],
        expiration_days: 14
      )

      freeze_time do
        get(:new, params: { event_id: event.friendly_id, template_id: template.hashid })

        expect(response).to have_http_status(:ok)
        body = response.parsed_body
        expect(body.at_css("[name='card_grant[email]']")["value"]).to be_nil
        expect(body.at_css("[name='card_grant[amount_cents]']")["value"]).to eq("42.50")
        expect(body.at_css("[name='card_grant[purpose]']")["value"]).to eq("Pizza night")
        expect(body.at_css("[name='card_grant[invite_message]']").text.strip).to eq("Enjoy!")
        expect(body.at_css("[type=checkbox][name='card_grant[one_time_use]']")["checked"]).to eq("checked")
        expect(body.at_css("[name='card_grant[merchant_lock]']")["value"]).to eq("123, 456")
        expect(body.at_css("[name='card_grant[category_lock]']")["value"]).to eq("fast_food_restaurants")
        expect(body.at_css("[name='card_grant[keyword_lock]']")["value"]).to eq("\\APizza")
        expect(body.at_css("[name='card_grant[banned_merchants]']")["value"]).to eq("789")
        expect(body.at_css("[name='card_grant[banned_categories]']")["value"]).to eq("betting_casino_gambling")
        expect(body.at_css("[name='card_grant[expiration_at]']")["value"]).to eq(14.days.from_now.to_date.iso8601)
        expect(body.at_css("[name='template_id']")["value"]).to eq(template.hashid)
      end
    end

    it "keeps Send grant as the form's default submit button" do
      user = create(:user)
      event = create(:event, plan_type: Event::Plan::HackClubAffiliate)
      create(:organizer_position, user:, event:)
      create_session(user, verified: true)

      get(:new, params: { event_id: event.friendly_id })

      form = response.parsed_body.at_css("form[action='#{event_card_grants_path(event)}']")
      expect(form.at_css("[name='template_name']")).to be_present
      expect(form.at_css("[type=submit]")["value"]).to eq("Send grant")
    end

    it "shows readers templates but not the controls for managing them" do
      user = create(:user)
      event = create(:event, plan_type: Event::Plan::HackClubAffiliate)
      create(:organizer_position, user:, event:, role: :reader)
      create_session(user, verified: true)
      template = create(:card_grant_template, event:, name: "Pizza")

      get(:new, params: { event_id: event.friendly_id, template_id: template.hashid })

      expect(response).to have_http_status(:ok)
      body = response.parsed_body
      expect(body.at_css("a[href='#{new_event_card_grant_path(event, template_id: template.hashid)}']").text.strip).to eq("Pizza")
      expect(body.at_css("[name='template_name']")).to be_nil
      expect(body.text).not_to include("Save as template")
      expect(body.at_css("a[href='#{event_card_grant_template_path(event, template)}']")).to be_nil
    end

    it "ignores templates from other events" do
      user = create(:user)
      event = create(:event)
      create(:organizer_position, user:, event:)
      create_session(user, verified: true)
      other_template = create(:card_grant_template, purpose: "Secret purpose")

      get(:new, params: { event_id: event.friendly_id, template_id: other_template.hashid })

      expect(response).to have_http_status(:ok)
      expect(response.parsed_body.at_css("[name='card_grant[purpose]']")["value"]).to be_nil
      expect(response.body).not_to include(other_template.name)
    end
  end

  describe "#card_index" do
    def create_grant(event:, full_name:, email:)
      user = create(:user, full_name:, email:)
      create(:card_grant, event:, user:, email:, purpose: "Pizza")
    end

    def search(event, query)
      get(:card_index, params: { event_id: event.friendly_id, q: query })
      expect(response).to have_http_status(:ok)
      response.parsed_body.css("a[href*='/spending']").map { |a| a["href"] }
    end

    it "lets organizers search by email and full name" do
      organizer = create(:user)
      event = create(:event, :with_positive_balance, plan_type: Event::Plan::HackClubAffiliate)
      create(:organizer_position, user: organizer, event:, role: :member)
      card_grant = create_grant(event:, full_name: "Orpheus Dinosaur", email: "orpheus@hackclub.com")
      create_session(organizer, verified: true)

      expect(search(event, "orpheus@hackclub.com")).to eq([spending_card_grant_path(card_grant)])
      expect(search(event, "Dinosaur")).to eq([spending_card_grant_path(card_grant)])
    end

    it "doesn't let non-organizers search by email or full name" do
      event = create(:event, :with_positive_balance, plan_type: Event::Plan::HackClubAffiliate)
      card_grant = create_grant(event:, full_name: "Orpheus Dinosaur", email: "orpheus@hackclub.com")

      expect(search(event, "orpheus@hackclub.com")).to be_empty
      expect(search(event, "Dinosaur")).to be_empty

      # ...but they can still search over what the page shows them.
      expect(search(event, "Pizza")).to eq([spending_card_grant_path(card_grant)])
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

    it "creates a card grant with usage restrictions" do
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
            merchant_lock: "123, 456",
            category_lock: "",
            keyword_lock: " \\AApple ",
            banned_merchants: "789",
            banned_categories: "betting_casino_gambling",
          },
        }
      )

      card_grant = event.card_grants.sole
      expect(card_grant.merchant_lock).to eq(["123", "456"])
      expect(card_grant.category_lock).to eq([])
      expect(card_grant.keyword_lock).to eq("\\AApple")
      expect(card_grant.banned_merchants).to eq(["789"])
      expect(card_grant.banned_categories).to eq(["betting_casino_gambling"])
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

    it "rejects an invalid merchant name lock" do
      user = create(:user)
      event = create(:event, :with_positive_balance, plan_type: Event::Plan::HackClubAffiliate)
      create(:card_grant_setting, event:)
      create(:organizer_position, user:, event:)
      create_session(user, verified: true)

      post(:create, params: { event_id: event.friendly_id, card_grant: { **card_grant_params, keyword_lock: "[unclosed" } })

      expect(event.card_grants).to be_empty
      expect(response).to have_http_status(:unprocessable_content)
      expect(flash[:error]).to eq("Keyword lock is not a valid regular expression")
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
end
