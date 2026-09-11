# frozen_string_literal: true

require "rails_helper"

# End-to-end proof that attribute-level authorization reaches the wire: the
# same serializer serves every viewer, and the policy alone decides which keys
# come back.
RSpec.describe Api::V5::AchTransfersController do
  render_views

  before do
    allow_any_instance_of(UsersHelper).to receive(:profile_picture_for).and_return("https://gravatar.com/avatar/stubbed")
  end

  let(:event) { create(:event, :with_positive_balance, is_public: transparent) }
  let(:transparent) { false }
  let(:creator) { create(:user, full_name: "Jane Doe") }
  let(:ach_transfer) do
    create(:ach_transfer, event:, creator:,
                          account_number: "123456789", routing_number: "110000000",
                          bank_name: "Big Bank", recipient_email: "payee@example.com")
  end

  def authenticate_as(user)
    request.headers["Authorization"] = "Bearer #{create(:api_token, user:).token}"
  end

  def show
    get :show, params: { id: ach_transfer.public_id }, as: :json
  end

  context "when signed out" do
    context "and the organization is private" do
      it "refuses" do
        show

        expect(response).to have_http_status(:forbidden)
      end
    end

    context "and the organization is transparent" do
      let(:transparent) { true }

      it "serves the public field set without a token" do
        show

        expect(response).to have_http_status(:ok)
        expect(response.parsed_body.keys).to match_array(
          %w[id object amount_cents date status recipient_name payment_for sender created_at]
        )
      end

      it "withholds counterparty and bank details" do
        show

        expect(response.parsed_body).not_to include(
          "recipient_email", "bank_name", "routing_number", "account_number_last4", "account_number"
        )
      end

      # The one field whose value narrows rather than disappearing.
      it "degrades the sender's name to initials" do
        show

        expect(response.parsed_body["sender"]).to include("name" => "Jane D")
        expect(response.parsed_body["sender"]).not_to include("email")
      end
    end
  end

  context "as a reader" do
    let(:user) { create(:user) }

    before do
      create(:organizer_position, user:, event:, role: :reader)
      authenticate_as(user)
    end

    it "adds the counterparty fields" do
      show

      expect(response).to have_http_status(:ok)
      expect(response.parsed_body).to include(
        "recipient_email" => "payee@example.com",
        "bank_name" => "Big Bank"
      )
    end

    it "still withholds account and routing numbers" do
      show

      expect(response.parsed_body).not_to include("routing_number", "account_number_last4")
    end
  end

  context "as a manager" do
    let(:user) { create(:user) }

    before do
      create(:organizer_position, user:, event:, role: :manager)
      authenticate_as(user)
    end

    it "adds the bank details, with the account number truncated" do
      show

      expect(response).to have_http_status(:ok)
      expect(response.parsed_body).to include(
        "routing_number" => "110000000",
        "account_number_last4" => "6789"
      )
    end

    # `:account_number` is in the policy's list because the web UI shows the
    # full number to a manager. The API deliberately does not emit it.
    it "never emits the full account number" do
      show

      expect(response.parsed_body).not_to include("account_number")
      expect(response.body).not_to include("123456789")
    end

    it "shows the sender's full name to someone in the same organization" do
      create(:organizer_position, user: creator, event:)

      show

      expect(response.parsed_body["sender"]).to include("name" => "Jane Doe")
    end
  end

  it "rejects a malformed token rather than falling back to anonymous" do
    request.headers["Authorization"] = "Bearer not-a-real-token"

    show

    expect(response).to have_http_status(:unauthorized)
  end


  describe "#index" do
    let!(:transparent_event) { create(:event, :with_positive_balance, is_public: true) }
    let!(:private_event)     { create(:event, :with_positive_balance, is_public: false) }
    let!(:transparent_ach)   { create(:ach_transfer, event: transparent_event, bank_name: "Open Bank") }
    let!(:private_ach)       { create(:ach_transfer, event: private_event, bank_name: "Closed Bank") }

    def index(**params)
      get :index, params: params, as: :json
    end

    it "lists only transparent organizations' transfers when signed out" do
      index

      expect(response).to have_http_status(:ok)
      expect(response.parsed_body.map { |t| t["id"] }).to contain_exactly(transparent_ach.public_id)
    end

    it "applies the same field gating to every row" do
      index

      expect(response.parsed_body.first).not_to include("bank_name", "routing_number")
      expect(response.body).not_to include("Open Bank")
    end

    it "includes the reader's own organization" do
      reader = create(:user)
      create(:organizer_position, user: reader, event: private_event, role: :reader)
      authenticate_as(reader)

      index

      expect(response.parsed_body.map { |t| t["id"] })
        .to contain_exactly(transparent_ach.public_id, private_ach.public_id)
    end

    # Filtering must narrow what the scope allows, never widen it.
    it "returns nothing for an organization the viewer cannot read" do
      index(organization_id: private_event.public_id)

      expect(response).to have_http_status(:ok)
      expect(response.parsed_body).to be_empty
    end
  end

end
