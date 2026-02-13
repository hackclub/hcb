# frozen_string_literal: true

require "rails_helper"

RSpec.describe Api::V4::CardGrantsController do
  render_views

  describe "#create" do
    def card_grant_params
      {
        amount_cents: "123_45",
        email: "recipient@example.com",
        keyword_lock: "some keywords",
        purpose: "Raffle prize",
        one_time_use: "true",
        pre_authorization_required: "true",
        instructions: "Here's a card grant for your raffle prize"
      }
    end

    it "creates a card grant" do
      user = create(:user, full_name: "Orpheus the Dinosaur", email: "orpheus@hackclub.com")
      event = create(:event, :with_positive_balance, name: "Test Event", plan_type: Event::Plan::HackClubAffiliate)
      create(:card_grant_setting, event:)
      create(:organizer_position, user:, event:)

      token = create(:api_token, user:)
      request.headers["Authorization"] = "Bearer #{token.token}"

      # `UsersHelper#profile_picture_for` uses `gravatar_url` if the user
      # hasn't uploaded an image. The background colour for the Gravatar
      # fallback image is determined by the user's ID, which makes the
      # response value unpredictable.
      allow_any_instance_of(UsersHelper).to receive(:gravatar_url).and_return("https://gravatar.com/avatar/stubbed")

      post(:create, params: { event_id: event.friendly_id, **card_grant_params, expand: "disbursements" }, as: :json)

      expect(response).to have_http_status(:created)
      card_grant = event.card_grants.sole
      disbursement = card_grant.disbursement
      recipient = card_grant.user

      serialized_event = {
        "id"                                => event.public_id,
        "parent_id"                         => nil,
        "name"                              => "Test Event",
        "slug"                              => "test-event",
        "background_image"                  => nil,
        "country"                           => nil,
        "created_at"                        => event.created_at.iso8601(3),
        "fee_percentage"                    => 0.0,
        "financially_frozen"                => false,
        "icon"                              => nil,
        "donation_page_available"           => true,
        "playground_mode"                   => false,
        "playground_mode_meeting_requested" => false,
        "transparent"                       => true
      }

      expect(response.parsed_body).to eq(
        {
          "id"                         => card_grant.public_id,
          "amount_cents"               => 123_45,
          "card_id"                    => nil,
          "one_time_use"               => true,
          "pre_authorization_required" => true,
          "status"                     => "active",
          "allowed_categories"         => [],
          "allowed_merchants"          => [],
          "category_lock"              => [],
          "merchant_lock"              => [],
          "purpose"                    => "Raffle prize",
          "keyword_lock"               => "some keywords",
          "email"                      => "recipient@example.com",
          "expires_on"                 => card_grant.expires_on.iso8601(3),
          "disbursements"              => [
            {
              "id"                      => disbursement.public_id,
              "memo"                    => "Grant to recipient",
              "status"                  => "completed",
              "transaction_id"          => disbursement.local_hcb_code.public_id,
              "outgoing_transaction_id" => disbursement.outgoing_disbursement.local_hcb_code.public_id,
              "incoming_transaction_id" => disbursement.incoming_disbursement.local_hcb_code.public_id,
              "amount_cents"            => 123_45,
              "card_grant_id"           => card_grant.public_id,
              "from"                    => serialized_event,
              "to"                      => serialized_event,
              "sender"                  => {
                "id"       => user.public_id,
                "name"     => "Orpheus D",
                "email"    => "orpheus@hackclub.com",
                "admin"    => false,
                "auditor"  => false,
                "avatar"   => "https://gravatar.com/avatar/stubbed",
                "birthday" => nil,
              },
            }
          ],
          "organization"               => serialized_event,
          "user"                       => {
            "id"      => recipient.public_id,
            "name"    => "recipient",
            "admin"   => false,
            "auditor" => false,
            "avatar"  => "https://gravatar.com/avatar/stubbed",
          },
        }
      )
    end

    it "reports validation errors" do
      user = create(:user, full_name: "Orpheus the Dinosaur", email: "orpheus@hackclub.com")
      event = create(:event, :with_positive_balance, name: "Test Event", plan_type: Event::Plan::HackClubAffiliate)
      create(:card_grant_setting, event:)
      create(:organizer_position, user:, event:)

      token = create(:api_token, user:)
      request.headers["Authorization"] = "Bearer #{token.token}"

      post(
        :create,
        params: {
          event_id: event.friendly_id,
          **card_grant_params,
          purpose: "This is a very long purpose that should exceed the 30 character limit",
        },
        as: :json
      )

      expect(response).to have_http_status(:unprocessable_entity)
      expect(response.parsed_body).to eq(
        {
          "error"    => "invalid_operation",
          "messages" => ["Purpose is too long (maximum is 30 characters)"]
        }
      )
    end

    it "handles downstream errors" do
      user = create(:user, full_name: "Orpheus the Dinosaur", email: "orpheus@hackclub.com")
      event = create(:event, :with_positive_balance, name: "Test Event", plan_type: Event::Plan::HackClubAffiliate)
      create(:card_grant_setting, event:)
      create(:organizer_position, user:, event:)

      token = create(:api_token, user:)
      request.headers["Authorization"] = "Bearer #{token.token}"

      post(
        :create,
        params: {
          event_id: event.friendly_id,
          **card_grant_params,
          amount_cents: 12_345_67,
        },
        as: :json
      )

      expect(response).to have_http_status(:unprocessable_entity)
      expect(response.parsed_body).to eq(
        {
          "error"    => "invalid_operation",
          "messages" => ["You don't have enough money to make this disbursement."]
        }
      )
    end
  end
end
