# frozen_string_literal: true

require "sidekiq/web"
require "sidekiq/cron/web"

Rails.application.routes.draw do
  # For details on the DSL available within this file, see https://guides.rubyonrails.org/routing.html
  get "up" => "rails/health#show", as: :rails_health_check
  get "/my_ip", to: "admin#my_ip"

  constraints AdminConstraint do
    mount Audits1984::Engine => "/console"
    mount Sidekiq::Web => "/sidekiq"
    mount Flipper::UI.app(Flipper), at: "flipper", as: "flipper"
  end
  constraints AuditorConstraint do
    mount Blazer::Engine, at: "blazer"
    mount SchemaEndpoint.instance => "/schema"
  end
  get "/sidekiq", to: redirect("users/auth") # fallback if adminconstraint fails, meaning user is not signed in
  if Rails.env.development?
    mount LetterOpenerWeb::Engine, at: "/letter_opener"
  end

  concern :commentable do
    resources :comments, shallow: true, except: [:show, :index] do
      resources :reactions, only: [:update], controller: "comment/reactions", action: "react"
    end
  end

  # API documentation
  namespace :docs do
    resources :api, only: [] do
      collection do
        # This crazy nesting is to get Rails to generate meaningful route helpers
        get "v3(/*path)", to: "api#v3"
        get "/", to: redirect("/docs/api/v3")
      end
    end
  end

  # V3 API
  mount Api::V3 => "/"

  root to: "static_pages#index"
  get "stats", to: "stats#stats"
  get "stats_custom_duration", to: "stats#stats_custom_duration"
  get "stats/admin_receipt_stats", to: "stats#admin_receipt_stats"
  get "project_stats", to: "stats#project_stats"
  get "bookkeeping", to: "admin#bookkeeping"
  get "stripe_charge_lookup", to: "static_pages#stripe_charge_lookup"

  resources :raffles, only: [:new, :create]

  resources :receipts, only: [:create, :destroy] do
    collection do
      post "link"
      get "link_modal"
    end

    member do
      post "reverse"
    end
  end

  scope :my do
    get "/", to: redirect("/"), as: :my

    get "settings", to: "users#edit", as: :my_settings
    get "settings/address", to: "users#edit_address"
    get "settings/payouts", to: "users#edit_payout"
    get "settings/previews", to: "users#edit_featurepreviews"
    get "settings/security", to: "users#edit_security"
    get "settings/notifications", to: "users#edit_notifications"
    get "settings/admin", to: "users#edit_admin"
    get "payroll", to: "my#payroll", as: :my_payroll

    get "feed", to: "my#feed", as: :my_feed
    get "inbox", to: "my#inbox", as: :my_inbox
    get "activities", to: "my#activities", as: :my_activities
    post "toggle_admin_activities", to: "my#toggle_admin_activities", as: :toggle_admin_activities
    post "hide_promotional_banner", to: "my#hide_promotional_banner", as: :hide_promotional_banner
    get "tasks", to: "my#tasks", as: :my_tasks
    get "reimbursements", to: "my#reimbursements", as: :my_reimbursements
    get "reimbursements_icon", to: "my#reimbursements_icon", as: :my_reimbursements_icon

    get "receipts", to: redirect("/my/inbox")
    post "receipts/upload", to: "static_pages#receipt", as: :my_receipts_upload
    get "missing_receipts", to: "my#missing_receipts_list", as: :my_missing_receipts_list
    get "missing_receipts_icon", to: "my#missing_receipts_icon", as: :my_missing_receipts_icon
    get "receipt_bin/suggested_pairings", to: "static_pages#suggested_pairings", as: :suggested_pairings

    post "receipt_report", to: "users#receipt_report", as: :trigger_receipt_report

    get "cards", to: "my#cards", as: :my_cards
    get "cards/shipping", to: "stripe_cards#shipping", as: :my_cards_shipping
  end

  resources :mailbox_addresses, only: [:create, :show] do
    member do
      post "activate"
    end
  end

  resources :suggested_pairings, only: [] do
    member do
      post "ignore"
      post "accept"
    end
  end

  post "receiptable/:receiptable_type/:receiptable_id/mark_no_or_lost", to: "receiptables#mark_no_or_lost", as: :receiptable_mark_no_or_lost

  # Feature-flags
  post "enable_feature", to: "features#enable_feature"
  post "disable_feature", to: "features#disable_feature"

  resources :users, only: [:show, :edit, :update], concerns: :commentable do
    collection do
      get "auth", to: "logins#new"
      get "webauthn/auth_options", to: "users#webauthn_options"
      post "toggle_pretend_is_not_admin", to: "users#toggle_pretend_is_not_admin"

      # SMS Auth
      post "start_sms_auth_verification", to: "users#start_sms_auth_verification"
      post "complete_sms_auth_verification", to: "users#complete_sms_auth_verification"
      post "toggle_sms_auth", to: "users#toggle_sms_auth"

      # Logout
      delete "logout", to: "users#logout"
      delete "logout_session", to: "users#logout_session"
      delete "revoke/:id", to: "users#revoke_oauth_application", as: "revoke_oauth_application"
      post "make_oauth_authorization_eternal/:id", to: "users#make_oauth_authorization_eternal", as: "make_authorization_eternal"

      # sometimes users refresh the login code page and get 404'd
      get "exchange_login_code", to: redirect("/users/auth", status: 301)
      get "login_code", to: redirect("/users/auth", status: 301)

      # For compatibility with the previous WebAuthn login flow
      get "webauthn", to: redirect("/users/auth")
    end
    member do
      get "address", to: "users#edit_address"
      get "payouts", to: "users#edit_payout"
      get "previews", to: "users#edit_featurepreviews"
      get "security", to: "users#edit_security"
      get "notifications", to: "users#edit_notifications"
      get "admin", to: "users#edit_admin"
      get "admin_details", to: "users#admin_details"

      delete "logout_all", to: "users#logout_all"

      post "impersonate"
      post "unimpersonate"
    end
    post "delete_profile_picture", to: "users#delete_profile_picture"
    post "generate_totp"
    post "enable_totp"
    post "disable_totp"
    post "generate_backup_codes"
    post "activate_backup_codes"
    post "disable_backup_codes"
    patch "stripe_cardholder_profile", to: "stripe_cardholders#update_profile"

    resources :webauthn_credentials, only: [:create, :destroy] do
      collection do
        get "register_options"
      end
    end
  end
  scope module: :users do
    resources "wrapped", only: :index do
      collection do
        get "data"
      end
    end
    resources :email_updates, only: [] do
      collection do
        get "verify"
        get "authorize", to: "email_updates#authorize_change"
      end
    end
  end

  resources :logins, only: [:new, :create] do
    collection do
      get "login_preference", to: "logins#choose_login_preference", as: :choose_login_preference
      post "complete" # for webauthn
      post "reauthenticate"
    end
    member do
      get "/", to: "logins#choose_login_preference", as: :choose_login_preference
      post "login_preference", to: "logins#set_login_preference", as: :set_login_preference

      # Request a login code
      post "login_code"

      # TOTP
      get "totp"
      post "totp"

      get "backup_code"
      post "backup_code"

      post "complete"
    end
  end

  resources :admin, only: [] do
    collection do
      get "bank_accounts", to: "admin#bank_accounts"
      get "hcb_codes", to: "admin#hcb_codes"
      get "bank_fees", to: "admin#bank_fees"
      get "users", to: "admin#users"
      get "raw_transactions", to: "admin#raw_transactions"
      get "raw_transaction_new", to: "admin#raw_transaction_new"
      post "raw_transaction_create", to: "admin#raw_transaction_create"
      get "raw_intrafi_transactions", to: "admin#raw_intrafi_transactions"
      post "raw_intrafi_transactions_import", to: "admin#raw_intrafi_transactions_import"
      get "ledger", to: "admin#ledger"
      get "stripe_cards", to: "admin#stripe_cards"
      get "pending_ledger", to: "admin#pending_ledger"
      get "ach", to: "admin#ach"
      get "reimbursements", to: "admin#reimbursements"
      get "payroll", to: "admin#payroll"
      get "stripe_card_personalization_designs", to: "admin#stripe_card_personalization_designs"
      get "stripe_card_personalization_design_new", to: "admin#stripe_card_personalization_design_new"
      post "stripe_card_personalization_design_create", to: "admin#stripe_card_personalization_design_create"
      get "checks", to: "admin#checks"
      get "increase_checks", to: "admin#increase_checks"
      get "paypal_transfers", to: "admin#paypal_transfers"
      get "wires", to: "admin#wires"
      get "wise_transfers", to: "admin#wise_transfers"
      get "events", to: "admin#events"
      get "event_new", to: "admin#event_new"
      get "event_new_from_airtable", to: "admin#event_new_from_airtable"
      post "event_create", to: "admin#event_create"
      post "event_create_from_airtable", to: "admin#event_create_from_airtable"
      get "donations", to: "admin#donations"
      get "recurring_donations", to: "admin#recurring_donations"
      get "disbursements", to: "admin#disbursements"
      get "disbursement_new", to: "admin#disbursement_new"
      get "invoices", to: "admin#invoices"
      get "sponsors", to: "admin#sponsors"
      get "google_workspaces", to: "admin#google_workspaces"
      post "google_workspaces_verify_all", to: "admin#google_workspaces_verify_all"
      get "balances", to: "admin#balances"
      get "hq_receipts", to: "admin#hq_receipts"
      get "account_numbers", to: "admin#account_numbers"
      get "employees", to: "admin#employees"
      get "employee_payments", to: "admin#employee_payments"
      get "emails", to: "admin#emails"
      get "email", to: "admin#email"
      get "merchant_memo_check", to: "admin#merchant_memo_check"
      get "referral_programs", to: "admin#referral_programs"
      post "referral_program_create", to: "admin#referral_program_create"
      get "unknown_merchants", to: "admin#unknown_merchants"
      post "request_balance_export", to: "admin#request_balance_export"
      get "active_teenagers_leaderboard", to: "admin#active_teenagers_leaderboard"
    end

    member do
      get "transaction", to: "admin#transaction"
      get "event_balance", to: "admin#event_balance"
      get "event_raised", to: "admin#event_raised"
      get "event_process", to: "admin#event_process"
      put "event_toggle_approved", to: "admin#event_toggle_approved"
      put "event_reject", to: "admin#event_reject"
      get "ach_start_approval", to: "admin#ach_start_approval"
      post "ach_approve", to: "admin#ach_approve"
      post "ach_send_realtime", to: "admin#ach_send_realtime"
      post "ach_reject", to: "admin#ach_reject"
      get "disbursement_process", to: "admin#disbursement_process"
      post "disbursement_approve", to: "admin#disbursement_approve"
      post "disbursement_reject", to: "admin#disbursement_reject"
      get "increase_check_process", to: "admin#increase_check_process"
      get "paypal_transfer_process", to: "admin#paypal_transfer_process"
      get "wire_process", to: "admin#wire_process"
      get "wise_transfer_process", to: "admin#wise_transfer_process"
      get "google_workspace_process", to: "admin#google_workspace_process"
      post "google_workspace_approve", to: "admin#google_workspace_approve"
      post "google_workspace_verify", to: "admin#google_workspace_verify"
      post "google_workspace_update", to: "admin#google_workspace_update"
      post "google_workspace_toggle_revocation_immunity", to: "admin#google_workspace_toggle_revocation_immunity"
      get "invoice_process", to: "admin#invoice_process"
      post "invoice_mark_paid", to: "admin#invoice_mark_paid"
    end
  end

  namespace :admin do
    root to: redirect("/admin/events")
    namespace :ledger_audits do
      resources :tasks, only: [:index, :show, :create] do
        post :reviewed
        post :flagged
      end
    end
    resources :ledger_audits, only: [:index, :show]
    resources :w9s, only: [:index, :new, :create]
    resources :check_deposits, only: [:index, :show] do
      post "submit", on: :member
      post "reject", on: :member
    end
    resources :column_statements, only: :index do
      get "bank_account_summary_report"
    end
    resources(:event_groups, only: [:index, :create, :destroy]) do
      collection do
        get("events/:event_id", as: :event, to: "event_groups#event")
        patch("events/:event_id", to: "event_groups#update_event")
      end
      member do
        get(:statement_of_activity)
      end
      resources(:event_group_memberships, path: "memberships", only: [:destroy])
    end
  end

  post "set_event", to: "admin#set_event_multiple_transactions", as: :set_event_multiple_transactions
  post "set_event/:id", to: "admin#set_event", as: :set_event
  post "set_paypal_transfer/:id", to: "admin#set_paypal_transfer", as: :set_paypal_transfer
  post "set_wire/:id", to: "admin#set_wire", as: :set_wire
  post "set_wise_transfer/:id", to: "admin#set_wise_transfer", as: :set_wise_transfer

  resources :organizer_position_invites, only: [:show], path: "invites" do
    post "accept"
    post "reject"
    post "cancel"
    post "resend"
    member do
      post "change_position_role"
    end
  end

  resources :organizer_position_contracts, only: [:create], path: "contracts" do
    member do
      post "void"
      post "resend_to_user"
      post "resend_to_cosigner"
    end
  end

  resources :organizer_positions, only: [:destroy], as: "organizers" do
    member do
      post "set_index"
      post "mark_visited"
      post "change_position_role"
    end

    resources :organizer_position_deletion_requests, only: [:new], as: "remove"
  end

  resources :organizer_position_deletion_requests, only: [:index, :show, :create], concerns: :commentable do
    post "close"
    post "open"
  end

  resources :g_suite_accounts, only: [:index, :create, :update, :edit, :destroy], path: "g_suite_accounts" do
    put "reset_password"
    put "toggle_suspension"
    resources :g_suite_aliases, only: [:create, :destroy], shallow: true
  end

  resources :g_suites, except: [:new, :create, :edit, :update] do
    resources :g_suite_accounts, only: [:create]
    resources :revocations, only: [:create, :destroy], controller: "g_suite/revocations"
  end

  resources :sponsors

  resources :invoices, only: [:show] do
    post "manually_mark_as_paid"
    post "archive"
    post "unarchive"
    post "void"
    get "hosted"
    get "pdf"
    member do
      post "refund"
    end
  end

  resources :stripe_cardholders, only: [:new, :create, :update]

  namespace :stripe_cards do
    resource :activation, only: [:new, :create], controller: :activation

    resources :personalization_designs, only: [:show] do
      member do
        post "make_common"
        post "make_unlisted"
      end
    end
  end
  resources :stripe_cards, only: %i[edit update create index show] do
    member do
      post "freeze"
      post "defrost"
      post "cancel"
      post "enable_cash_withdrawal"
      get "ephemeral_keys"
    end
  end

  resources :emburse_cards, except: %i[new create]

  resources :checks, only: [:show]

  resources :increase_checks, only: [] do
    member do
      post "approve"
      post "reject"
    end
  end

  resources :paypal_transfers, only: [] do
    member do
      post "approve"
      post "reject"
      post "mark_failed"
    end
  end

  resources :wires, only: [:edit, :update] do
    member do
      post "approve"
      post "send", to: "wires#send_wire"
      post "reject"
    end
  end

  resources :wise_transfers, only: [:edit, :update] do
    member do
      post "approve"
      post "reject"
      post "mark_sent"
      post "mark_failed"
    end

    collection do
      get "generate_quote"
    end
  end

  resources :ach_transfers, only: [:show] do
    member do
      post "cancel"
      post "toggle_speed"
    end
    collection do
      post "validate_routing_number"
    end
    get "confirmation", to: "ach_transfers#transfer_confirmation_letter"
  end

  resources :disbursements, only: [:new, :create, :show, :edit, :update] do
    post "mark_fulfilled"
    post "reject"
    post "cancel"
    post "set_transaction_categories"
    get "confirmation", to: "disbursements#transfer_confirmation_letter"
  end

  get "disbursements", to: redirect("/admin/disbursements")

  resources :documents, except: [:index] do
    collection do
      get "", to: "documents#common_index", as: :common
    end
    get "download"
    post "toggle", to: "documents#toggle_archive"
  end

  resources :bank_accounts, only: [:new, :create, :update, :show, :index] do
    get "reauthenticate"
  end

  resources :hcb_codes, path: "/hcb", only: [:show, :edit, :update], concerns: :commentable do
    member do
      post "comment"
      get "attach_receipt"
      get "memo_frame"
      get "dispute"
      get "receipt_status"
      post "invoice_as_personal_transaction"
      post "pin"
      post "toggle_tag/:tag_id", to: "hcb_codes#toggle_tag", as: :toggle_tag
      post "send_receipt_sms", to: "hcb_codes#send_receipt_sms", as: :send_sms_receipt

      scope module: "hcb_code" do
        get "subscriptions/transactions", to: "subscriptions#transactions"
      end
    end
  end

  scope module: "hcb_code" do
    namespace :tag do
      resources :suggestions, only: [] do
        post "accept"
        post "reject"
      end
    end
  end

  resources :canonical_pending_transactions, only: [:show, :edit, :update] do
    member do
      post "set_category"
    end
  end

  resources :canonical_transactions, only: [:show, :edit] do
    member do
      post "waive_fee"
      post "unwaive_fee"
      post "mark_bank_fee"
      post "set_custom_memo"
      post "set_category"
    end
  end

  resources :exports do
    collection do
      get "collect_email", to: "exports#collect_email", as: "collect_email"
      get ":event", to: "exports#transactions", as: "transactions"
      get "reimbursements/:event", to: "exports#reimbursements", as: "reimbursements"
    end
  end

  resources :transactions, only: [:index, :show, :edit, :update]

  namespace :reimbursement do
    resources :reports, only: [:show, :create, :edit, :update, :destroy] do
      post "request_reimbursement"
      post "admin_approve"
      post "admin_send_wise_transfer"
      post "reverse"
      post "approve_all_expenses"
      post "request_changes"
      post "reject"
      post "submit"
      post "update_currency"
      post "draft"
      get "wise_transfer_quote"
      collection do
        post "quick_expense"
        get "/:event_name/finished", to: "reports#finished", as: "finished"
      end
    end

    get "start/:event_name", to: "reports#start", as: "start_reimbursement_report"

    resources :expenses, only: [:create, :edit, :update, :destroy] do
      post "approve"
      post "unapprove"
    end
  end

  resources :reimbursement_reports, only: [], path: "reimbursements/reports", concerns: :commentable

  resources :employees do
    post "terminate"
    post "onboard"
  end

  namespace :employee do
    resources :payments do
      post "review"
      get "stub"
    end
  end

  get "brand_guidelines", to: redirect("branding")
  get "branding", to: "static_pages#branding"
  get "security", to: "static_pages#security"
  get "faq", to: redirect("https://help.hcb.hackclub.com")
  get "roles", to: "static_pages#roles"
  get "admin_tools", to: "static_pages#admin_tools"
  get "audit", to: "admin#audit"

  resources :emburse_card_requests, path: "emburse_card_requests", except: [:new, :create] do
    collection do
      get "export"
    end
    post "reject"
    post "cancel"
  end

  resources :emburse_transfers, except: [:new, :create] do
    collection do
      get "export"
    end
    post "accept"
    post "reject"
    post "cancel"
  end

  resources :emburse_transactions, only: [:index, :edit, :update, :show]

  resources :donations, only: [:show, :update] do
    collection do
      get "start/:event_name", to: "donations#start_donation", as: "start_donation"
      post "start/:event_name", to: "donations#make_donation", as: "make_donation"
      get "start/:event_name/tiers/:tier_id", to: "donations#start_donation", as: "start_donation_tier"
      get "qr/:event_name.png", to: "donations#qr_code", as: "qr_code"
      get ":event_name/:donation", to: "donations#finish_donation", as: "finish_donation"
      get ":event_name/:donation/finished", to: "donations#finished", as: "finished_donation"
      get "export"
      get "export_donors"
    end

    member do
      post "refund", to: "donations#refund"
    end
  end

  use_doorkeeper scope: "api/v4/oauth" do
    skip_controllers :authorized_applications
  end
  use_doorkeeper_device_authorization_grant scope: "api/v4/oauth"

  namespace :api do
    namespace :v4 do
      defaults format: :json do
        resource :user, only: [] do
          get "/", to: "users#me", as: "user"
          resources :events, path: "organizations", only: [:index]
          resources :stripe_cards, path: "cards", only: [:index]
          resources :card_grants, only: [:index]
          resources :invitations, only: [:index, :show] do
            member do
              post "accept"
              post "reject"
            end
          end

          get "transactions/missing_receipt", to: "transactions#missing_receipt"
          get :available_icons
        end

        resources :users, only: [:show] do
          collection do
            get "/by_email/:email", to: "users#by_email", as: "by_email", constraints: { email: /[^\/]+/ }
          end
        end

        resources :events, path: "organizations", only: [:show] do
          resources :stripe_cards, path: "cards", only: [:index]
          resources :card_grants, only: [:index, :create]
          resources :invoices, only: [:index]
          resources :sponsors, only: [:index]
          resources :transactions, only: [:show, :update] do
            resources :receipts, only: [:index]
            resources :comments, only: [:index, :create]

            member do
              get "memo_suggestions"
            end
          end

          resources :disbursements, path: "transfers", only: [:create]

          resources :donations, path: "donations", only: [:create]

          member do
            get "transactions"
            get :followers
          end
        end

        resources :transactions, only: [:show]
        resources :receipts, only: [:create, :index, :destroy]

        resources :stripe_cards, path: "cards", only: [:show, :update, :create] do
          member do
            get "transactions"
            get "ephemeral_keys"
            post "cancel"
          end
        end

        resources :card_grants, only: [:show, :update] do
          member do
            post "topup"
            post "withdraw"
            post "cancel"
          end
        end

        resources :invoices, only: [:show, :create]

        resources :sponsors, only: [:show, :create]

        get "stripe_terminal_connection_token", to: "stripe_terminal#connection_token"

        match "*path" => "application#not_found", via: [:get, :post]
      end
    end
  end

  post "api/v1/users/find", to: "api#user_find"
  post "api/v1/events/create_demo", to: "api#create_demo_event"
  get "api/current_user", to: "api#the_current_user"
  get "api/flags", to: "api#flags"

  post "twilio/webhook", to: "twilio#webhook"
  post "stripe/webhook", to: "stripe#webhook"
  post "docuseal/webhook", to: "docuseal#webhook"
  post "webhooks/column", to: "column/webhooks#webhook"

  post "extract/invoice", to: "extraction#invoice"

  get "negative_events", to: "admin#negative_events"

  get "admin_task_size", to: "admin#task_size"
  get "admin_search", to: redirect("/admin/users")
  post "admin_search", to: redirect("/admin/users")

  resources :tours, only: [] do
    member do
      post "mark_complete"
      post "set_step"
    end
  end

  resources :recurring_donations, only: [:show, :edit, :update], path: "recurring" do
    member do
      post "cancel"
    end
  end

  resources :card_grants, only: [:show, :edit, :update], path: "grants", concerns: :commentable do
    member do
      post "activate"
      get "spending"
      post "clear_purpose"
    end

    scope module: "card_grant" do
      resource :pre_authorizations, only: [:show, :update] do
        member do
          post "clear_screenshots"
          post "organizer_approve"
          post "organizer_reject"
        end
      end
    end
  end

  match "/400", to: "errors#bad_request", via: :all
  match "/404", to: "errors#not_found", via: :all
  match "/500", to: "errors#internal_server_error", via: :all
  match "/504", to: "errors#timeout", via: :all
  get "timeout", to: "errors#timeout", via: :all

  Rack::Utils::HTTP_STATUS_CODES.keys.select { |c| c >= 400 }.each do |code|
    match "/#{code}", to: "errors#error", via: :all, code:
  end

  get "/search" => "search#index"

  resources :follows, only: [:destroy], controller: "event/follows"

  resources :announcements, except: [:index, :new] do
    member do
      post "publish"
    end
  end

  namespace "announcements" do
    resources :blocks, only: [:create, :edit, :update, :show] do
      member do
        post "refresh"
      end
    end
  end

  get "/events" => "events#index"
  resources :events, except: [:new, :create, :edit], concerns: :commentable, path: "/" do

    # Loaded as Turbo frames on the home page
    get :team_stats
    get :recent_activity
    get :balance_transactions
    get :money_movement
    get :merchants_chart
    get :categories_chart
    get :top_categories
    get :tags_chart
    get :users_chart
    get :transaction_heatmap

    get "edit", to: redirect("/%{event_id}/settings")
    get "transactions"
    get "ledger"
    get "merchants_filter"
    put "toggle_hidden"
    post "claim_point_of_contact"
    post "create_sub_organization"

    post "remove_header_image"
    post "remove_background_image"
    post "remove_logo"

    get "team"
    get "google_workspace", to: "events#g_suite_overview", as: :g_suite_overview
    post "g_suite_create"
    put "g_suite_verify"
    get "emburse_cards", to: "events#emburse_card_overview", as: :emburse_cards_overview
    get "cards", to: "events#card_overview", as: :cards_overview
    get "cards/new", to: "stripe_cards#new"
    get "announcements", to: "events#announcement_overview", as: :announcement_overview
    get "announcements/new", to: "announcements#new"
    get "feed", to: "events#feed", as: :feed
    get "stripe_cards/shipping", to: "stripe_cards#shipping", as: :stripe_cards_shipping

    resources :follows, only: [:create], controller: "event/follows"

    get "transfers/new", to: "events#new_transfer"

    get "async_balance"
    get "reimbursements_pending_review_icon"

    get "documentation", to: redirect("/%{event_id}/documents", status: 302)
    get "transfers"
    get "statements"
    get "statement_of_activity"
    get "promotions"
    get "reimbursements"
    get "employees"
    get "sub_organizations"
    get "donations", to: "events#donation_overview", as: :donation_overview
    get "activation_flow", to: "events#activation_flow", as: :activation_flow
    post "activate", to: "events#activate", as: :activate
    resources :disbursements, only: [:new, :create]
    resources :increase_checks, only: [:new, :create], path: "checks"
    resources :fees, only: [:create]
    resources :paypal_transfers, only: [:new, :create]
    resources :wires, only: [:new, :create]
    resources :wise_transfers, only: [:new, :create]
    resources :ach_transfers, only: [:new, :create]
    resources :organizer_position_invites,
              only: [:new, :create],
              path: "invites"
    resources :g_suites, only: [:new, :create, :edit, :update]
    resources :documents, only: [:index]
    get "fiscal_sponsorship_letter", to: "documents#fiscal_sponsorship_letter"
    get "verification_letter", to: "documents#verification_letter"
    resources :invoices, only: [:new, :create, :index]
    resources :affiliations, only: [:create, :update, :destroy], controller: "event/affiliations"
    resources :tags, only: [:create, :update, :destroy]
    resources :event_tags, only: [:create, :destroy]

    namespace :donation do
      resource :goals, only: [:create, :update]
      resource :tiers, only: [:create, :update, :destroy] do
        post :set_index, on: :member
      end
    end

    resources :recurring_donations, only: [:create], path: "recurring" do
      member do
        get "pay"
        get "finished"
      end
    end

    resources :check_deposits, only: [:index, :create], path: "check-deposits" do
      member do
        post "toggle_fronted"
      end
    end

    resources :card_grants, only: [:new, :create], path: "card-grants" do
      member do
        post "topup"
        post "withdraw"
        post "cancel"
        post "convert_to_reimbursement_report"
        post "toggle_one_time_use"
        post "disable_pre_authorization"

        get "edit/overview", to: "card_grants#edit_overview"
        get "edit/usage_restrictions", to: "card_grants#edit_usage_restrictions"
        get "edit/purpose", to: "card_grants#edit_purpose"
        get "edit/actions", to: "card_grants#edit_actions"
        get "edit/balance", to: "card_grants#edit_balance"
        get "edit/topup", to: "card_grants#edit_topup"
        get "edit/withdraw", to: "card_grants#edit_withdraw"


      end
    end

    resource :column_account_number, controller: "column/account_number", only: [:create, :update], path: "account-number"

    resources :organizer_positions, path: "team", only: [] do
      resources :organizer_position_deletion_requests, path: "removal-requests", as: "remove", only: [:new]

      scope module: "organizer_position" do
        namespace :spending do
          resources :controls do
            resources :allowances, only: [:new, :create], controller: "control/allowances"
          end
        end
      end
    end

    resources :payment_recipients, only: [:destroy]

    member do
      get "account-number", to: "events#account_number"
      post "toggle_event_tag/:event_tag_id", to: "events#toggle_event_tag", as: :toggle_event_tag
      get "audit_log"
      post "validate_slug"
      get "termination"

      get "settings(/:tab)", to: "events#edit", as: :edit
    end

    get "balance_by_date"
  end

  scope module: "referral" do
    resources :programs, only: [:show], path: "referrals"
    resources :programs, only: [:show], path: "from/*slug"
  end

  # rewrite old event urls to the new ones not prefixed by /events/
  get "/events/*path", to: redirect("/%{path}", status: 302)

  # Beware: Routes after "resources :events" might be overwritten by a
  # similarly named event
end
