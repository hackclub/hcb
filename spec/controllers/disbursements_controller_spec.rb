# frozen_string_literal: true

require "rails_helper"

RSpec.describe DisbursementsController do
  include SessionSupport
  render_views

  describe "#create" do
    it "creates a disbursement" do
      sender = create(:user)
      source_event = create(:event, :with_positive_balance)
      create(:organizer_position, user: sender, event: source_event)

      destination_event = create(:event)
      create(:organizer_position, user: sender, event: destination_event)

      create_session(sender, verified: true)

      expect do
        post(
          :create,
          params: {
            disbursement: {
              name: "Boba Drops",
              source_event_id: source_event.public_id,
              event_id: destination_event.public_id,
              amount: "123.45"
            }
          }
        )
      end.to change(Disbursement, :count).by(1)

      expect(flash[:success]).to eq("Transfer successfully requested.")
      expect(response).to redirect_to(event_transfers_path(source_event))

      disbursement = Disbursement.last
      expect(disbursement.name).to eq("Boba Drops")
      expect(disbursement.amount).to eq(123_45)
      expect(disbursement.source_event).to eq(source_event)
      expect(disbursement.destination_event).to eq(destination_event)
    end

    it "allows sending to a public organization the user doesn't manage, pending review" do
      sender = create(:user)
      source_event = create(:event, :with_positive_balance, organizers: [sender])
      destination_event = create(:event, is_public: true, is_indexable: true)
      create_session(sender, verified: true)

      expect do
        post(:create, params: { disbursement: { name: "Claude", source_event_id: source_event.public_id, event_id: destination_event.public_id, amount: "40" } })
      end.to change(Disbursement, :count).by(1)

      expect(Disbursement.last.aasm_state).to eq("reviewing")
    end

    it "allows sending to an unlisted transparent organization the user doesn't manage, pending review" do
      sender = create(:user)
      source_event = create(:event, :with_positive_balance, organizers: [sender])
      destination_event = create(:event, is_public: true, is_indexable: false)
      create_session(sender, verified: true)

      expect do
        post(:create, params: { disbursement: { name: "Claude", source_event_id: source_event.public_id, event_id: destination_event.slug, amount: "40" } })
      end.to change(Disbursement, :count).by(1)

      expect(Disbursement.last.aasm_state).to eq("reviewing")
    end

    it "only fronts transfers into organizations the user manages" do
      sender = create(:user)
      source_event = create(:event, :with_positive_balance, organizers: [sender], plan_type: Event::Plan::HackClubAffiliate)
      own_event = create(:event, organizers: [sender])
      readable_event = create(:event)
      create(:organizer_position, user: sender, event: readable_event, role: :reader)
      public_event = create(:event)
      create_session(sender, verified: true)

      post(:create, params: { disbursement: { name: "Own", source_event_id: source_event.public_id, event_id: own_event.public_id, amount: "40" } })
      expect(Disbursement.last.canonical_pending_transactions.map(&:fronted)).to eq([true, true])

      post(:create, params: { disbursement: { name: "Readable", source_event_id: source_event.public_id, event_id: readable_event.public_id, amount: "40" } })
      expect(Disbursement.last.canonical_pending_transactions.map(&:fronted)).to eq([false, false])

      post(:create, params: { disbursement: { name: "Public", source_event_id: source_event.public_id, event_id: public_event.public_id, amount: "40" } })
      expect(Disbursement.last.canonical_pending_transactions.map(&:fronted)).to eq([false, false])
    end

    it "rejects sending to a financially frozen organization the user doesn't manage" do
      sender = create(:user)
      source_event = create(:event, :with_positive_balance, organizers: [sender])
      destination_event = create(:event, financially_frozen: true)
      create_session(sender, verified: true)

      expect do
        post(:create, params: { disbursement: { name: "Claude", source_event_id: source_event.public_id, event_id: destination_event.public_id, amount: "40" } })
      end.not_to change(Disbursement, :count)

      expect(flash[:error]).to eq("You are not authorized to perform this action.")
    end

    it "rejects a transfer without a source organization" do
      sender = create(:user)
      destination_event = create(:event)
      create_session(sender, verified: true)

      expect do
        post(:create, params: { disbursement: { name: "Claude", event_id: destination_event.public_id, amount: "40" } })
      end.not_to change(Disbursement, :count)

      expect(flash[:error]).to eq("You are not authorized to perform this action.")
    end

    it "keeps the form filled in when the transfer can't be created" do
      sender = create(:user)
      source_event = create(:event, organizers: [sender])
      destination_event = create(:event)
      create_session(sender, verified: true)

      expect do
        post(:create, params: { disbursement: { name: "Claude", source_event_id: source_event.public_id, event_id: destination_event.public_id, amount: "40" } })
      end.not_to change(Disbursement, :count)

      expect(response).to have_http_status(:unprocessable_content)
      expect(flash.now[:error]).to eq("You don't have enough money to make this disbursement.")
      expect(response.body).to include('value="Claude"', 'value="40.0"', destination_event.public_id)
    end

    it "rejects sending to a private organization the user doesn't manage" do
      sender = create(:user)
      source_event = create(:event, :with_positive_balance, organizers: [sender])
      destination_event = create(:event, is_public: false)
      create_session(sender, verified: true)

      expect do
        post(:create, params: { disbursement: { name: "Claude", source_event_id: source_event.public_id, event_id: destination_event.public_id, amount: "40" } })
      end.not_to change(Disbursement, :count)

      expect(flash[:error]).to eq("You are not authorized to perform this action.")
    end

    it "allows transaction categories to be set by admins" do
      sender = create(:user, :make_admin)
      create(:governance_admin_transfer_limit, user: sender)
      source_event = create(:event, :with_positive_balance)
      create(:organizer_position, user: sender, event: source_event)

      destination_event = create(:event)

      create_session(sender, verified: true)

      expect do
        post(
          :create,
          params: {
            disbursement: {
              name: "Boba Drops",
              source_event_id: source_event.public_id,
              event_id: destination_event.public_id,
              amount: "123.45",
              source_transaction_category_slug: "donations",
              destination_transaction_category_slug: "fundraising",
            }
          }
        )
      end.to change(Disbursement, :count).by(1)

      expect(flash[:success]).to eq("Transfer successfully requested.")
      expect(response).to redirect_to(disbursements_admin_index_path)

      disbursement = Disbursement.last
      expect(disbursement.name).to eq("Boba Drops")
      expect(disbursement.amount).to eq(123_45)
      expect(disbursement.source_event).to eq(source_event)
      expect(disbursement.destination_event).to eq(destination_event)
      expect(disbursement.source_transaction_category.slug).to eq("donations")
      expect(disbursement.destination_transaction_category.slug).to eq("fundraising")
    end
  end

  describe "#set_transaction_categories" do
    it "allows categories to be set by admins" do
      admin = create(:user, :make_admin)
      disbursement = create(:disbursement)

      create_session(admin, verified: true)

      post(
        :set_transaction_categories,
        params: {
          disbursement_id: disbursement.id,
          disbursement: {
            source_transaction_category_slug: "donations",
            destination_transaction_category_slug: "fundraising",
          }
        },
        format: :html
      )

      expect(response).to redirect_to(disbursement_path(disbursement))

      disbursement.reload
      expect(disbursement.source_transaction_category.slug).to eq("donations")
      expect(disbursement.destination_transaction_category.slug).to eq("fundraising")
    end

    it "clears the categories if the param is blank" do
      admin = create(:user, :make_admin)
      disbursement = create(
        :disbursement,
        source_transaction_category: TransactionCategory.find_or_create_by!(slug: "donations"),
        destination_transaction_category: TransactionCategory.find_or_create_by!(slug: "fundraising"),
      )

      create_session(admin, verified: true)

      post(
        :set_transaction_categories,
        params: {
          disbursement_id: disbursement.id,
          disbursement: {
            source_transaction_category_slug: "",
            destination_transaction_category_slug: "",
          }
        },
        format: :html
      )

      expect(response).to redirect_to(disbursement_path(disbursement))

      disbursement.reload
      expect(disbursement.source_transaction_category).to be_nil
      expect(disbursement.destination_transaction_category).to be_nil
    end

    it "allows one category to be set without affecting the other" do
      admin = create(:user, :make_admin)
      disbursement = create(
        :disbursement,
        source_transaction_category: TransactionCategory.find_or_create_by!(slug: "donations"),
        destination_transaction_category: TransactionCategory.find_or_create_by!(slug: "fundraising"),
      )

      create_session(admin, verified: true)

      post(
        :set_transaction_categories,
        params: {
          disbursement_id: disbursement.id,
          disbursement: {
            destination_transaction_category_slug: "rent",
          }
        },
        format: :html
      )

      expect(response).to redirect_to(disbursement_path(disbursement))

      disbursement.reload
      expect(disbursement.source_transaction_category.slug).to eq("donations")
      expect(disbursement.destination_transaction_category.slug).to eq("rent")
    end
  end

  describe "#new" do
    it "opens a prefilled link to a public organization the user doesn't manage" do
      sender = create(:user)
      create(:event, organizers: [sender])
      destination_event = create(:event, name: "Claude Clearinghouse")
      create_session(sender, verified: true)

      get(:new, params: { event_id: destination_event.slug, amount: "4000", message: "Claude — October 2026" })

      expect(response).to have_http_status(:ok)
      expect(response.body).to include('value="Claude — October 2026"', 'value="40.0"', destination_event.public_id)
    end

    it "rejects a prefilled private destination the user doesn't manage" do
      sender = create(:user)
      source_event = create(:event, organizers: [sender])
      destination_event = create(:event, is_public: false)
      create_session(sender, verified: true)

      get(:new, params: { source_event_id: source_event.slug, event_id: destination_event.slug })

      expect(response).to redirect_to(root_path)
      expect(flash[:error]).to eq("You are not authorized to perform this action.")
    end
  end

  describe "#event_search" do
    it "suggests an unlisted transparent organization the user is a member of, without a query" do
      member = create(:user)
      source_event = create(:event, organizers: [member])
      destination_event = create(:event, name: "Claude Unlisted", is_indexable: false)
      create(:organizer_position, user: member, event: destination_event, role: :member)
      create(:event, name: "Claude Private Member", is_public: false).tap do |e|
        create(:organizer_position, user: member, event: e, role: :member)
      end
      create_session(member, verified: true)

      get(:event_search, format: :json)
      expect(JSON.parse(response.body).map { |o| o["value"] }).to contain_exactly(source_event.public_id, destination_event.public_id)

      get(:event_search, params: { q: "Claude" }, format: :json)
      expect(JSON.parse(response.body).map { |o| o["value"] }).to eq([destination_event.public_id])

      # Sources are still limited to organizations the user manages.
      get(:event_search, params: { sending: true }, format: :json)
      expect(JSON.parse(response.body).map { |o| o["value"] }).to eq([source_event.public_id])
    end

    it "lists public organizations as destinations but hides private, unlisted and demo ones" do
      user = create(:user)
      create(:event, organizers: [user])
      public_event = create(:event, name: "Claude Clearinghouse")
      create(:event, name: "Claude Private", is_public: false)
      create(:event, name: "Claude Unlisted", is_indexable: false)
      create(:event, name: "Claude Demo", demo_mode: true)
      create_session(user, verified: true)

      get(:event_search, params: { q: "Claude" }, format: :json)
      expect(JSON.parse(response.body).map { |o| o["value"] }).to eq([public_event.public_id])

      get(:event_search, params: { q: "Claude", sending: true }, format: :json)
      expect(JSON.parse(response.body)).to be_empty
    end

    it "hides financially frozen organizations" do
      user = create(:user)
      create(:event, name: "Claude Frozen", financially_frozen: true)
      create(:event, name: "Claude Frozen Unlisted", slug: "claude-frozen-unlisted", is_indexable: false, financially_frozen: true)
      create_session(user, verified: true)

      get(:event_search, params: { q: "Claude" }, format: :json)
      expect(JSON.parse(response.body)).to be_empty

      get(:event_search, params: { q: "claude-frozen-unlisted" }, format: :json)
      expect(JSON.parse(response.body)).to be_empty
    end

    it "only shows balances for the user's own organizations" do
      user = create(:user)
      own_event = create(:event, name: "Claude Budget", organizers: [user])
      public_event = create(:event, name: "Claude Clearinghouse")
      create_session(user, verified: true)

      get(:event_search, params: { q: "Claude" }, format: :json)
      sublabels = JSON.parse(response.body).to_h { |o| [o["value"], o["sublabel"]] }
      expect(sublabels[own_event.public_id]).to be_present
      expect(sublabels[public_event.public_id]).to be_nil
    end

    it "treats a non-string query as text" do
      user = create(:user)
      create_session(user, verified: true)

      get(:event_search, params: { q: ["Claude"] }, format: :json)
      expect(response).to have_http_status(:ok)
    end

    it "only lists the user's own organizations before they search" do
      user = create(:user)
      own_event = create(:event, organizers: [user])
      create(:event, name: "Claude Clearinghouse")
      create_session(user, verified: true)

      get(:event_search, format: :json)
      expect(JSON.parse(response.body).map { |o| o["value"] }).to eq([own_event.public_id])
    end

    it "finds an unlisted transparent organization by its exact slug, but not a private one" do
      user = create(:user)
      create_session(user, verified: true)
      unlisted_event = create(:event, name: "Claude Unlisted", is_indexable: false)
      private_event = create(:event, name: "Claude Private", is_public: false)

      get(:event_search, params: { q: unlisted_event.slug }, format: :json)
      expect(JSON.parse(response.body).map { |o| o["value"] }).to eq([unlisted_event.public_id])

      get(:event_search, params: { q: unlisted_event.slug.first(8) }, format: :json)
      expect(JSON.parse(response.body)).to be_empty

      get(:event_search, params: { q: private_event.slug }, format: :json)
      expect(JSON.parse(response.body)).to be_empty
    end

    it "ranks the user's own organizations above other prefix matches" do
      user = create(:user)
      own_event = create(:event, name: "My Claude Budget", organizers: [user])
      public_event = create(:event, name: "Claude Clearinghouse")
      create_session(user, verified: true)

      get(:event_search, params: { q: "Claude" }, format: :json)
      expect(JSON.parse(response.body).map { |o| o["value"] }).to eq([own_event.public_id, public_event.public_id])
    end

    it "ranks the exact match first even when substring matches would trim it" do
      admin = create(:user, :make_admin)
      create_session(admin, verified: true)

      create(:event, name: "ysws - aaa")
      create(:event, name: "ysws - bbb")
      create(:event, name: "ysws - ccc")
      exact = create(:event, name: "ysws")

      get(:event_search, params: { q: "ysws" }, format: :json)

      expect(response).to have_http_status(:ok)
      labels = JSON.parse(response.body).map { |o| o["label"] }
      expect(labels.first).to eq("ysws (ID: #{exact.id})")
    end

    it "paginates results without overlap across pages" do
      stub_const("ComboboxSearchable::PAGE_SIZE", 2)
      admin = create(:user, :make_admin)
      create_session(admin, verified: true)

      3.times { |i| create(:event, name: "ysws #{i}") }

      get(:event_search, params: { q: "ysws", page: 1 }, format: :json)
      page1 = JSON.parse(response.body).map { |o| o["value"] }
      get(:event_search, params: { q: "ysws", page: 2 }, format: :json)
      page2 = JSON.parse(response.body).map { |o| o["value"] }

      expect(page1.size).to eq(2)
      expect(page2.size).to eq(1)
      expect(page1 & page2).to be_empty
    end

    it "clamps non-positive page numbers to the first page" do
      stub_const("ComboboxSearchable::PAGE_SIZE", 2)
      admin = create(:user, :make_admin)
      create_session(admin, verified: true)

      3.times { |i| create(:event, name: "ysws #{i}") }

      get(:event_search, params: { q: "ysws", page: 0 }, format: :json)
      expect(JSON.parse(response.body).size).to eq(2)
    end
  end

  describe "#show" do
    it "renders and resolves the comment thread HcbCode via the outgoing hcb_code" do
      auditor = create(:user, :make_auditor)
      disbursement = create(:disbursement)

      create_session(auditor, verified: true)

      get(:show, params: { id: disbursement.id })

      expect(response).to have_http_status(:ok)
      # The show action find-or-creates the comment thread's HcbCode from the
      # outgoing hcb_code (the legacy `hcb_code` alias was removed).
      expect(HcbCode.exists?(hcb_code: disbursement.outgoing_hcb_code)).to be(true)
    end
  end
end
