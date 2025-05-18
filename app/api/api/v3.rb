# frozen_string_literal: true

module Api
  class V3 < Grape::API
    include Grape::Kaminari

    version "v3", using: :path
    prefix :api
    format :json
    default_format :json

    helpers do
      def orgs
        @orgs ||= paginate(Event.indexable.order(created_at: :asc))
      end

      def activities
        @activities ||= paginate(PublicActivity::Activity.joins("LEFT JOIN \"events\" ON activities.event_id = events.id OR (activities.recipient_id = events.id AND recipient_type = 'Event')").where({ events: { is_public: true, is_indexable: true } }).order(created_at: :desc))
      end

      def org
        @org ||=
          begin
            id = params[:organization_id]
            event ||= Event.transparent.find_by_public_id id # by public id (ex. org_1234). Will NOT error if not found
            event ||= Event.transparent.friendly.find_by_friendly_id id # by slug. Will error if not found
          end
      rescue ActiveRecord::RecordNotFound
        error!({ message: "Organization not found." }, 404)
      end

      def transactions
        # TODO: this can be optimized
        @transactions ||=
          begin
            pending = PendingTransactionEngine::PendingTransaction::All.new(event_id: org.id).run
            settled = TransactionGroupingEngine::Transaction::All.new(event_id: org.id).run

            combined = paginate(Kaminari.paginate_array(pending + settled))
            combined.map(&:local_hcb_code)
          end
      end

      def transaction
        @transaction ||=
          begin
            id = params[:transaction_id]
            HcbCode.find_by_public_id!(id)
          end
      rescue ActiveRecord::RecordNotFound
        error!({ message: "Transaction not found." }, 404)
      end

      def card_charges
        # TODO: this can be optimized
        @card_charges ||=
          begin
            pending = PendingTransactionEngine::PendingTransaction::All.new(event_id: org.id).run
            settled = TransactionGroupingEngine::Transaction::All.new(event_id: org.id).run

            combined = pending + settled
            combined.select! { |t| t.local_hcb_code.type == :card_charge }
            combined = paginate(Kaminari.paginate_array(combined))
            combined.map do |t|
              Models::CardCharge.find_by_hcb_code(t.hcb_code)
            end
          end
      end

      def card_charge
        @card_charge ||=
          begin
            id = params[:card_charge_id]
            Models::CardCharge.find_by_public_id!(id)
          end
      rescue ActiveRecord::RecordNotFound
        error!({ message: "Card charge not found." }, 404)
      end

      def donations
        @donations ||= paginate(org.donations.not_pending.order(created_at: :desc))
      end

      def donation
        @donation ||=
          begin
            id = params[:donation_id]
            Donation.find_by_public_id!(id)
          end
      rescue ActiveRecord::RecordNotFound
        error!({ message: "Donation not found." }, 404)
      end

      def transfers
        @transfers ||= paginate(org.disbursements)
      end

      def transfer
        @transfer ||=
          begin
            id = params[:transfer_id]
            Disbursement.find_by_public_id!(id)
          end
      rescue ActiveRecord::RecordNotFound
        error!({ message: "Transfer not found." }, 404)
      end

      def ach_transfers
        @ach_transfers ||= paginate(org.ach_transfers.order(created_at: :desc))
      end

      def ach_transfer
        @ach_transfer ||=
          begin
            id = params[:ach_transfer_id]
            AchTransfer.find_by_public_id!(id)
          end
      rescue ActiveRecord::RecordNotFound
        error!({ message: "ACH transfer not found." }, 404)
      end

      def invoices
        @invoices ||= paginate(org.invoices.order(created_at: :desc))
      end

      def invoice
        @invoice ||=
          begin
            id = params[:invoice_id]
            Invoice.find_by_public_id!(id)
          end
      rescue ActiveRecord::RecordNotFound
        error!({ message: "Invoice not found." }, 404)
      end

      def checks
        @checks ||= paginate(org.checks.order(created_at: :desc))
      end

      def check
        @check ||=
          begin
            id = params[:check_id]
            Check.find_by_public_id!(id)
          end
      rescue ActiveRecord::RecordNotFound
        error!({ message: "Check not found." }, 404)
      end

      def cards
        @cards ||= paginate(org.stripe_cards.order(created_at: :desc))
      end

      def card
        @card ||=
          begin
            id = params[:card_id]
            StripeCard.find_by_public_id!(id)
          end
      rescue ActiveRecord::RecordNotFound
        error!({ message: "Card not found." }, 404)
      end

      def activity
        @activity ||=
          begin
            id = params[:activity_id]
            PublicActivity::Activity.find_by_public_id!(id)
          end
      rescue ActiveRecord::RecordNotFound
        error!({ message: "Activity not found." }, 404)
      end

      # FOR TYPE EXPANSION
      def type_expansion(expand: [], hide: [])
        {
          expand: (params[:expand] || []) + expand,
          hide: (params[:hide] || []) + hide
        }
      end

      params :expand do
        # TODO: it see like the `Array` type is broken. It won't show on Stoplight
        optional :expand,
                 types: [String, Array[String]],
                 # TODO: this `coerce_with` is temporarily really messy because it needs to handle both processing strings and arrays of strings
                 coerce_with: ->(x) {
                   [x].flatten.compact.map { |type| type.split(",") }
                      .flatten.map { |type| type.strip.underscore }
                 },
                 desc: "Object types to expand in the API response (separated by commas)"

        optional :hide,
                 types: [String, Array[String]],
                 # TODO: this `coerce_with` is temporarily really messy because it needs to handle both processing strings and arrays of strings
                 coerce_with: ->(x) {
                   [x].flatten.compact.map { |type| type.split(",") }
                      .flatten.map { |type| type.strip.underscore }
                 },
                 documentation: { hidden: true }
      end
    end

    mount Directory

    desc "Flavor text!" do
      summary "Flavor text!"
      failure [[404]]
      hidden true
    end
    get :flavor do
      {
        flavor: FlavorTextService.new.generate
      }
    end

    desc "Git" do
      summary "Get the commit hash of the latest build."
      failure [[404]]
      hidden true
    end
    get :git do
      {
        commit_time: Build.timestamp,
        commit_hash: Build.commit_hash
      }
    end

    desc "Return a list of transparent organizations" do
      summary "Get a list of transparent organizations"
      detail "Returns a list of organizations in <a href='https://changelog.hcb.hackclub.com/transparent-finances-(optional-feature)-151427'><strong>Transparency Mode</strong></a> that have opted in to public listing."
      failure [[404]]
      is_array true
      produces ["application/json"]
      consumes ["application/json"]
      success Entities::Organization
      tags ["Organizations"]
      nickname "list-transparent-organizations"
    end
    params do
      use :pagination, per_page: 50, max_per_page: 100
      use :expand
    end
    get :organizations do
      present orgs, with: Api::Entities::Organization, **type_expansion(expand: %w[organization user])
    end

    desc "Return a list of recent activities" do
      summary "Get a list of recent activities on transparent HCB organizations"
      detail "Returns a list of recent activities from all HCB organizations that are in <a href='https://changelog.hcb.hackclub.com/transparent-finances-(optional-feature)-151427'><strong>Transparency Mode</strong></a> and have opted in to public listing."
      failure [[404]]
      is_array true
      produces ["application/json"]
      consumes ["application/json"]
      success Entities::Activity
      tags ["Activities"]
      nickname "list-activities"
    end
    params do
      use :pagination, per_page: 50, max_per_page: 100
      use :expand
    end
    get :activities do
      present activities, with: Api::Entities::Activity, **type_expansion(expand: %w[organization transaction])
    end

    resource :organizations do
      desc "Return a transparent organization" do
        summary "Get a single organization"
        detail "The organization must be in <a href='https://changelog.hcb.hackclub.com/transparent-finances-(optional-feature)-151427'><strong>Transparency Mode</strong></a>."
        produces ["application/json"]
        consumes ["application/json"]
        success Entities::Organization
        failure [[404, "Organization not found. Check the id/slug and make sure Transparency Mode is on.", Entities::ApiError]]
        tags ["Organizations"]
        nickname "get-a-single-organization"
      end
      params do
        requires :organization_id, type: String, desc: "Organization ID or slug."
        use :expand
      end
      route_param :organization_id do
        get do
          begin
            Pundit.authorize(nil, [:api, org], :show?)
            present org, with: Api::Entities::Organization, **type_expansion(expand: %w[organization user])
          rescue ActiveRecord::RecordNotFound, ArgumentError
            error!({ message: "Organization not found." }, 404)
          end
        end

        resource :transactions do
          desc "Return a list of transactions" do
            summary "List an organization's transactions"
            detail "Transaction represent a line item on an Organization's ledger. There are various <em>types</em> of transaction (see the <em>type</em> below).<br/><br/>"
            produces ["application/json"]
            consumes ["application/json"]
            is_array true
            success Entities::Transaction
            failure [[404, "Organization not found. Check the id/slug and make sure Transparency Mode is on.", Entities::ApiError]]
            tags ["Transactions"]
            nickname "list-an-organizations-transactions"
          end
          params do
            use :pagination, per_page: 50, max_per_page: 100
            use :expand
          end
          get do
            Pundit.authorize(nil, [:api, org], :transactions?)
            present transactions, with: Api::Entities::Transaction, **type_expansion(expand: %w[transaction]), org:
          end
        end

        resource :card_charges do
          desc "Return a list of card charges" do
            summary "List an organization's card charges"
            detail "Transactions created using an HCB card."
            produces ["application/json"]
            consumes ["application/json"]
            is_array true
            success Entities::CardCharge
            failure [[404, "Organization not found. Check the id/slug and make sure Transparency Mode is on.", Entities::ApiError]]
            tags ["Card Charges"]
            nickname "list-an-organizations-card-charges"
          end
          params do
            use :pagination, per_page: 50, max_per_page: 100
            use :expand
          end
          get do
            Pundit.authorize(nil, [:api, org], :card_charges?)
            present card_charges, with: Api::Entities::CardCharge, **type_expansion(expand: %w[card_charge])
          end
        end

        resource :donations do
          desc "Return a list of donations" do
            summary "List an organization's donations"
            detail ""
            produces ["application/json"]
            consumes ["application/json"]
            is_array true
            success Entities::Donation
            failure [[404, "Organization not found. Check the id/slug and make sure Transparency Mode is on.", Entities::ApiError]]
            tags ["Donations"]
            nickname "list-an-organizations-donations"
          end
          params do
            use :pagination, per_page: 50, max_per_page: 100
            use :expand
          end
          get do
            Pundit.authorize(nil, [:api, org], :donations?)
            present donations, with: Api::Entities::Donation, **type_expansion(expand: %w[donation])
          end
        end

        resource :transfers do
          desc "Return a list of transfers" do
            summary "List an organization's transfers"
            detail ""
            produces ["application/json"]
            consumes ["application/json"]
            is_array true
            success Entities::Transfer
            failure [[404, "Organization not found. Check the id/slug and make sure Transparency Mode is on.", Entities::ApiError]]
            tags ["Transfers"]
            nickname "list-an-organizations-transfers"
          end
          params do
            use :pagination, per_page: 50, max_per_page: 100
            use :expand
          end
          get do
            Pundit.authorize(nil, [:api, org], :transfers?)
            present transfers, with: Api::Entities::Transfer, **type_expansion(expand: %w[transfer])
          end
        end

        resource :invoices do
          desc "Return a list of invoices" do
            summary "List an organization's invoices"
            detail ""
            produces ["application/json"]
            consumes ["application/json"]
            is_array true
            success Entities::Invoice
            failure [[404, "Organization not found. Check the id/slug and make sure Transparency Mode is on.", Entities::ApiError]]
            tags ["Invoices"]
            nickname "list-an-organizations-invoices"
          end
          params do
            use :pagination, per_page: 50, max_per_page: 100
            use :expand
          end
          get do
            Pundit.authorize(nil, [:api, org], :invoices?)
            present invoices, with: Api::Entities::Invoice, **type_expansion(expand: %w[invoice])
          end
        end

        resource :ach_transfers do
          desc "Return a list of ACH transfers" do
            summary "List an organization's ACH transfers"
            detail ""
            produces ["application/json"]
            consumes ["application/json"]
            is_array true
            success Entities::AchTransfer
            failure [[404, "Organization not found. Check the id/slug and make sure Transparency Mode is on.", Entities::ApiError]]
            tags ["ACH Transfers"]
            nickname "list-an-organizations-ach-transfers"
          end
          params do
            use :pagination, per_page: 50, max_per_page: 100
            use :expand
          end
          get do
            Pundit.authorize(nil, [:api, org], :ach_transfers?)
            present ach_transfers, with: Api::Entities::AchTransfer, **type_expansion(expand: %w[ach_transfer])
          end
        end

        resource :checks do
          desc "Return a list of checks" do
            summary "List an organization's checks"
            detail ""
            produces ["application/json"]
            consumes ["application/json"]
            is_array true
            success Entities::Check
            failure [[404, "Organization not found. Check the id/slug and make sure Transparency Mode is on.", Entities::ApiError]]
            tags ["Checks"]
            nickname "list-an-organizations-checks"
          end
          params do
            use :pagination, per_page: 50, max_per_page: 100
            use :expand
          end
          get do
            Pundit.authorize(nil, [:api, org], :checks?)
            present checks, with: Api::Entities::Check, **type_expansion(expand: %w[check])
          end
        end

        resource :cards do
          desc "Return a list of cards" do
            summary "List an organization's cards"
            detail ""
            produces ["application/json"]
            consumes ["application/json"]
            is_array true
            success Entities::Card
            failure [[404, "Organization not found. Check the id/slug and make sure Transparency Mode is on.", Entities::ApiError]]
            tags ["Cards"]
            nickname "list-an-organizations-cards"
          end
          params do
            use :pagination, per_page: 50, max_per_page: 100
            use :expand
          end
          get do
            Pundit.authorize(nil, [:api, org], :cards?)
            present cards, with: Api::Entities::Card, **type_expansion(expand: %w[card])
          end
        end

      end

    end

    resource :card_charges do
      desc "Return a card charge" do
        summary "Get a card charge"
        detail ""
        produces ["application/json"]
        consumes ["application/json"]
        success Entities::CardCharge
        failure [[404, "Card charge not found. Check the ID.", Entities::ApiError]]
        tags ["Card Charges"]
        nickname "get-a-card-charge"
      end
      params do
        requires :card_charge_id, type: String, desc: "Card charge ID"
        use :expand
      end
      route_param :card_charge_id do
        get do
          Pundit.authorize(nil, [:api, card_charge], :show?, policy_class: Api::CardChargePolicy)
          present card_charge, with: Api::Entities::CardCharge, **type_expansion(expand: %w[card_charge])
        end
      end
    end

    resource :donations do
      desc "Return a single donation" do
        summary "Get a single donation"
        detail ""
        produces ["application/json"]
        consumes ["application/json"]
        success Entities::Donation
        failure [[404, "Donation not found. Check the ID.", Entities::ApiError]]
        tags ["Donations"]
        nickname "get-a-single-donation"
      end
      params do
        requires :donation_id, type: String, desc: "Donation ID"
        use :expand
      end
      route_param :donation_id do
        get do
          Pundit.authorize(nil, [:api, donation], :show?)
          present donation, with: Api::Entities::Donation, **type_expansion(expand: %w[donation])
        end
      end
    end

    resource :transfers do
      desc "Return a single transfer" do
        summary "Get a single transfer"
        detail ""
        produces ["application/json"]
        consumes ["application/json"]
        success Entities::Transfer
        failure [[404, "Transfer not found. Check the ID.", Entities::ApiError]]
        tags ["Transfers"]
        nickname "get-a-single-transfer"
      end
      params do
        requires :transfer_id, type: String, desc: "Transfer ID"
        use :expand
      end
      route_param :transfer_id do
        get do
          Pundit.authorize(nil, [:api, transfer], :show?)
          present transfer, with: Api::Entities::Transfer, **type_expansion(expand: %w[transfer])
        end
      end
    end

    resource :invoices do
      desc "Return a single invoice" do
        summary "Get a single invoice"
        detail ""
        produces ["application/json"]
        consumes ["application/json"]
        success Entities::Invoice
        failure [[404, "Invoice not found. Check the ID.", Entities::ApiError]]
        tags ["Invoices"]
        nickname "get-a-single-invoice"
      end
      params do
        requires :invoice_id, type: String, desc: "Invoice ID"
        use :expand
      end
      route_param :invoice_id do
        get do
          Pundit.authorize(nil, [:api, invoice], :show?)
          present invoice, with: Api::Entities::Invoice, **type_expansion(expand: %w[invoice])
        end
      end
    end

    resource :ach_transfers do
      desc "Return a single ACH transfer" do
        summary "Get a single ACH transfer"
        detail ""
        produces ["application/json"]
        consumes ["application/json"]
        success Entities::AchTransfer
        failure [[404, "ACH transfer not found. Check the ID.", Entities::ApiError]]
        tags ["ACH Transfers"]
        nickname "get-a-single-ach-transfer"
      end
      params do
        requires :ach_transfer_id, type: String, desc: "ACH transfer ID"
        use :expand
      end
      route_param :ach_transfer_id do
        get do
          Pundit.authorize(nil, [:api, ach_transfer], :show?)
          present ach_transfer, with: Api::Entities::AchTransfer, **type_expansion(expand: %w[ach_transfer])
        end
      end
    end

    resource :checks do
      desc "Return a single check" do
        summary "Get a single check"
        detail ""
        produces ["application/json"]
        consumes ["application/json"]
        success Entities::Check
        failure [[404, "Check not found. Check the ID.", Entities::ApiError]]
        tags ["Checks"]
        nickname "get-a-single-check"
      end
      params do
        requires :check_id, type: String, desc: "Check ID"
        use :expand
      end
      route_param :check_id do
        get do
          Pundit.authorize(nil, [:api, check], :show?)
          present check, with: Api::Entities::Check, **type_expansion(expand: %w[check])
        end
      end
    end

    resource :cards do
      desc "Return a single card" do
        summary "Get a single card"
        detail ""
        produces ["application/json"]
        consumes ["application/json"]
        success Entities::Card
        failure [[404, "Card not found. Check the ID.", Entities::ApiError]]
        tags ["Cards"]
        nickname "get-a-single-card"
      end
      params do
        requires :card_id, type: String, desc: "Card ID"
        use :expand
      end
      route_param :card_id do
        get do
          Pundit.authorize(nil, [:api, card], :show?)
          present card, with: Api::Entities::Card, **type_expansion(expand: %w[card])
        end
      end
    end

    resource :transactions do
      desc "Return a single transaction" do
        summary "Get a single transaction"
        detail ""
        produces ["application/json"]
        consumes ["application/json"]
        success Entities::Transaction
        failure [[404, "Transaction not found. Check the ID.", Entities::ApiError]]
        tags ["Transactions"]
        nickname "get-a-single-transaction"
      end
      params do
        requires :transaction_id, type: String, desc: "Transaction ID"
        use :expand
      end
      route_param :transaction_id do
        get do
          Pundit.authorize(nil, [:api, transaction], :show?)
          present transaction, with: Api::Entities::Transaction, **type_expansion(expand: %w[transaction])
        end
      end
    end

    resource :activities do
      desc "Return a single activity" do
        summary "Get a single activity"
        detail ""
        produces ["application/json"]
        consumes ["application/json"]
        success Entities::Activity
        failure [[404, "Activity not found. Check the ID.", Entities::ApiError]]
        tags ["Activities"]
        nickname "get-a-single-activity"
      end
      params do
        requires :activity_id, type: String, desc: "Activity ID"
        use :expand
      end
      route_param :activity_id do
        get do
          present activity, with: Api::Entities::Activity, **type_expansion(expand: %w[organization transaction])
        end
      end
    end

    # Handle validation errors
    rescue_from Grape::Exceptions::ValidationErrors do |e|
      error!({ message: e.message }, 400)
    end

    # Handle 404 errors (catch all)
    route :any, "*path" do
      error!({ message: "Path not found. Please see the documentation (https://hcb.hackclub.com/docs/api/v3/) for all available paths." }, 404)
    end

    # Handle unexpected errors
    rescue_from ActiveRecord::RecordNotFound do
      error!({ message: "Not found." }, 404)
    end
    rescue_from Pundit::NotAuthorizedError do
      error!({ message: "Not authorized." }, 403)
    end
    rescue_from :all do |e|
      Rails.error.report(e, handled: false, severity: :error, context: "api")

      # Provide error message in api response ONLY in development mode
      msg = if Rails.env.development?
              e.message
            else
              "A server error has occurred."
            end
      error!({ message: msg }, 500)
    end

    add_swagger_documentation(
      info: {
        title: "The HCB API",
        description: "The HCB API is an unauthenticated REST API that allows you to read public information
                      from organizations with <a href='https://changelog.hcb.hackclub.com/transparent-finances-(optional-feature)-151427'>Transparency Mode</a>
                      enabled.
                      <br><br><strong>Questions or suggestions?</strong>
                      <br>Reach us in the #hcb channel on the <a href='https://hackclub.com/slack'>Hack Club Slack</a>
                      or email <a href='mailto:hcb@hackclub.com'>hcb@hackclub.com</a>.
                      <br><br>Happy hacking! ✨",
        contact_name: "HCB",
        contact_email: "hcb@hackclub.com",
      },
      doc_version: "3.0.0",
      models: [
        Entities::Organization,
        Entities::Transaction,
        Entities::CardCharge,
        Entities::AchTransfer,
        Entities::Check,
        Entities::Transfer,
        Entities::Donation,
        Entities::Invoice,
        Entities::Card,
        Entities::User,
        Entities::Activity,
        Entities::ApiError
      ],
      array_use_braces: true,
      tags: [
        {
          name: "Organizations",
        },
        {
          name: "Transactions",
        },
        {
          name: "Card Charges",
        },
        {
          name: "Donations",
        },
        {
          name: "Invoices",
        },
        {
          name: "Checks",
        },
        {
          name: "ACH Transfers",
        },
        {
          name: "Transfers"
        },
        {
          name: "Cards"
        },
        {
          name: "Activities"
        }
      ]
    )

  end
end
