# frozen_string_literal: true

# This file is auto-generated from the current state of the database. Instead
# of editing this file, please use the migrations feature of Active Record to
# incrementally modify your database, and then regenerate this schema definition.
#
# This file is the source Rails uses to define your schema when running `bin/rails
# db:schema:load`. When creating a new database, `bin/rails db:schema:load` tends to
# be faster and is potentially less error prone than running all of your
# migrations from scratch. Old migrations may fail to apply correctly if those
# migrations use external dependencies or application code.
#
# It's strongly recommended that you check this file into your version control system.

ActiveRecord::Schema[8.0].define(version: 2026_01_31_204827) do
  create_schema "google_sheets"

  # These are extensions that must be enabled in order to support this database
  enable_extension "citext"
  enable_extension "pg_catalog.plpgsql"
  enable_extension "pg_stat_statements"

  create_table "ach_transfers", force: :cascade do |t|
    t.string "aasm_state"
    t.string "account_number_bidx"
    t.text "account_number_ciphertext"
    t.integer "amount"
    t.datetime "approved_at", precision: nil
    t.string "bank_name"
    t.text "column_id"
    t.string "company_entry_description"
    t.string "company_name"
    t.text "confirmation_number"
    t.datetime "created_at", precision: nil, null: false
    t.bigint "creator_id"
    t.bigint "event_id"
    t.text "increase_id"
    t.date "invoiced_at"
    t.text "payment_for"
    t.bigint "payment_recipient_id"
    t.bigint "processor_id"
    t.string "recipient_email"
    t.string "recipient_name"
    t.string "recipient_tel"
    t.datetime "rejected_at", precision: nil
    t.string "routing_number_bidx"
    t.text "routing_number_ciphertext"
    t.boolean "same_day", default: false, null: false
    t.datetime "scheduled_arrival_date", precision: nil
    t.date "scheduled_on"
    t.boolean "send_email_notification", default: false
    t.datetime "updated_at", precision: nil, null: false
    t.index ["account_number_bidx"], name: "index_ach_transfers_on_account_number_bidx"
    t.index ["column_id"], name: "index_ach_transfers_on_column_id", unique: true
    t.index ["creator_id"], name: "index_ach_transfers_on_creator_id"
    t.index ["event_id"], name: "index_ach_transfers_on_event_id"
    t.index ["increase_id"], name: "index_ach_transfers_on_increase_id", unique: true
    t.index ["payment_recipient_id"], name: "index_ach_transfers_on_payment_recipient_id"
    t.index ["processor_id"], name: "index_ach_transfers_on_processor_id"
    t.index ["routing_number_bidx"], name: "index_ach_transfers_on_routing_number_bidx"
  end

  create_table "action_mailbox_inbound_emails", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.string "message_checksum", null: false
    t.string "message_id", null: false
    t.integer "status", default: 0, null: false
    t.datetime "updated_at", null: false
    t.index ["message_id", "message_checksum"], name: "index_action_mailbox_inbound_emails_uniqueness", unique: true
  end

  create_table "active_storage_attachments", force: :cascade do |t|
    t.bigint "blob_id", null: false
    t.datetime "created_at", precision: nil, null: false
    t.string "name", null: false
    t.bigint "record_id", null: false
    t.string "record_type", null: false
    t.index ["blob_id"], name: "index_active_storage_attachments_on_blob_id"
    t.index ["record_type", "record_id", "name", "blob_id"], name: "index_active_storage_attachments_uniqueness", unique: true
  end

  create_table "active_storage_blobs", force: :cascade do |t|
    t.bigint "byte_size", null: false
    t.string "checksum"
    t.string "content_type"
    t.datetime "created_at", precision: nil, null: false
    t.string "filename", null: false
    t.string "key", null: false
    t.text "metadata"
    t.string "service_name", null: false
    t.index ["key"], name: "index_active_storage_blobs_on_key", unique: true
  end

  create_table "active_storage_variant_records", force: :cascade do |t|
    t.bigint "blob_id", null: false
    t.string "variation_digest", null: false
    t.index ["blob_id", "variation_digest"], name: "index_active_storage_variant_records_uniqueness", unique: true
  end

  create_table "activities", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.bigint "event_id"
    t.string "key"
    t.bigint "owner_id"
    t.string "owner_type"
    t.text "parameters"
    t.bigint "recipient_id"
    t.string "recipient_type"
    t.bigint "trackable_id"
    t.string "trackable_type"
    t.datetime "updated_at", null: false
    t.index ["event_id"], name: "index_activities_on_event_id"
    t.index ["owner_id", "owner_type"], name: "index_activities_on_owner_id_and_owner_type"
    t.index ["owner_type", "owner_id"], name: "index_activities_on_owner"
    t.index ["recipient_id", "recipient_type"], name: "index_activities_on_recipient_id_and_recipient_type"
    t.index ["recipient_type", "recipient_id"], name: "index_activities_on_recipient"
    t.index ["trackable_id", "trackable_type"], name: "index_activities_on_trackable_id_and_trackable_type"
    t.index ["trackable_type", "trackable_id"], name: "index_activities_on_trackable"
  end

  create_table "admin_ledger_audit_tasks", force: :cascade do |t|
    t.bigint "admin_ledger_audit_id"
    t.datetime "created_at", null: false
    t.bigint "hcb_code_id"
    t.bigint "reviewer_id"
    t.string "status", default: "pending"
    t.datetime "updated_at", null: false
    t.index ["admin_ledger_audit_id"], name: "index_admin_ledger_audit_tasks_on_admin_ledger_audit_id"
    t.index ["hcb_code_id"], name: "index_admin_ledger_audit_tasks_on_hcb_code_id"
    t.index ["reviewer_id"], name: "index_admin_ledger_audit_tasks_on_reviewer_id"
  end

  create_table "admin_ledger_audits", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.date "start"
    t.datetime "updated_at", null: false
  end

  create_table "ahoy_events", force: :cascade do |t|
    t.string "name"
    t.jsonb "properties"
    t.datetime "time", precision: nil
    t.bigint "user_id"
    t.bigint "visit_id"
    t.index ["name", "time"], name: "index_ahoy_events_on_name_and_time"
    t.index ["properties"], name: "index_ahoy_events_on_properties", opclass: :jsonb_path_ops, using: :gin
    t.index ["user_id"], name: "index_ahoy_events_on_user_id"
    t.index ["visit_id"], name: "index_ahoy_events_on_visit_id"
  end

  create_table "ahoy_messages", force: :cascade do |t|
    t.text "content"
    t.string "mailer"
    t.datetime "sent_at"
    t.text "subject"
    t.string "to"
    t.bigint "user_id"
    t.string "user_type"
    t.index ["to"], name: "index_ahoy_messages_on_to"
    t.index ["user_type", "user_id"], name: "index_ahoy_messages_on_user"
  end

  create_table "ahoy_visits", force: :cascade do |t|
    t.string "app_version"
    t.string "browser"
    t.string "city"
    t.string "country"
    t.string "device_type"
    t.string "ip"
    t.text "landing_page"
    t.float "latitude"
    t.float "longitude"
    t.string "os"
    t.string "os_version"
    t.string "platform"
    t.text "referrer"
    t.string "referring_domain"
    t.string "region"
    t.datetime "started_at", precision: nil
    t.text "user_agent"
    t.bigint "user_id"
    t.string "utm_campaign"
    t.string "utm_content"
    t.string "utm_medium"
    t.string "utm_source"
    t.string "utm_term"
    t.string "visit_token"
    t.string "visitor_token"
    t.index ["user_id"], name: "index_ahoy_visits_on_user_id"
    t.index ["visit_token"], name: "index_ahoy_visits_on_visit_token", unique: true
  end

  create_table "announcement_blocks", force: :cascade do |t|
    t.bigint "announcement_id", null: false
    t.datetime "created_at", null: false
    t.jsonb "parameters"
    t.text "rendered_email_html"
    t.text "rendered_html"
    t.string "type", null: false
    t.datetime "updated_at", null: false
    t.index ["announcement_id"], name: "index_announcement_blocks_on_announcement_id"
  end

  create_table "announcements", force: :cascade do |t|
    t.string "aasm_state"
    t.bigint "author_id", null: false
    t.jsonb "content", null: false
    t.datetime "created_at", null: false
    t.datetime "deleted_at", precision: nil
    t.bigint "event_id", null: false
    t.datetime "published_at"
    t.string "template_type"
    t.string "title", null: false
    t.datetime "updated_at", null: false
    t.index ["author_id"], name: "index_announcements_on_author_id"
    t.index ["event_id"], name: "index_announcements_on_event_id"
  end

  create_table "api_tokens", force: :cascade do |t|
    t.bigint "application_id"
    t.datetime "created_at", null: false
    t.integer "expires_in"
    t.string "refresh_token"
    t.datetime "revoked_at"
    t.string "scopes"
    t.string "token_bidx"
    t.text "token_ciphertext"
    t.datetime "updated_at", null: false
    t.bigint "user_id", null: false
    t.index ["application_id"], name: "index_api_tokens_on_application_id"
    t.index ["token_bidx"], name: "index_api_tokens_on_token_bidx", unique: true
    t.index ["user_id"], name: "index_api_tokens_on_user_id"
  end

  create_table "audits1984_audits", force: :cascade do |t|
    t.bigint "auditor_id", null: false
    t.datetime "created_at", null: false
    t.text "notes"
    t.bigint "session_id", null: false
    t.integer "status", default: 0, null: false
    t.datetime "updated_at", null: false
    t.index ["auditor_id"], name: "index_audits1984_audits_on_auditor_id"
    t.index ["session_id"], name: "index_audits1984_audits_on_session_id"
  end

  create_table "bank_accounts", force: :cascade do |t|
    t.datetime "created_at", precision: nil, null: false
    t.datetime "failed_at", precision: nil
    t.integer "failure_count", default: 0
    t.boolean "is_positive_pay"
    t.text "name"
    t.text "plaid_access_token_ciphertext"
    t.text "plaid_account_id"
    t.text "plaid_item_id"
    t.boolean "should_sync", default: true
    t.boolean "should_sync_v2", default: false
    t.datetime "updated_at", precision: nil, null: false
  end

  create_table "bank_fees", force: :cascade do |t|
    t.string "aasm_state"
    t.integer "amount_cents"
    t.datetime "created_at", null: false
    t.bigint "event_id", null: false
    t.bigint "fee_revenue_id"
    t.string "hcb_code"
    t.datetime "updated_at", null: false
    t.index ["event_id"], name: "index_bank_fees_on_event_id"
    t.index ["fee_revenue_id"], name: "index_bank_fees_on_fee_revenue_id"
  end

  create_table "blazer_audits", force: :cascade do |t|
    t.datetime "created_at", precision: nil
    t.string "data_source"
    t.bigint "query_id"
    t.text "statement"
    t.bigint "user_id"
    t.index ["query_id"], name: "index_blazer_audits_on_query_id"
    t.index ["user_id"], name: "index_blazer_audits_on_user_id"
  end

  create_table "blazer_checks", force: :cascade do |t|
    t.string "check_type"
    t.datetime "created_at", null: false
    t.bigint "creator_id"
    t.text "emails"
    t.datetime "last_run_at", precision: nil
    t.text "message"
    t.bigint "query_id"
    t.string "schedule"
    t.text "slack_channels"
    t.string "state"
    t.datetime "updated_at", null: false
    t.index ["creator_id"], name: "index_blazer_checks_on_creator_id"
    t.index ["query_id"], name: "index_blazer_checks_on_query_id"
  end

  create_table "blazer_dashboard_queries", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.bigint "dashboard_id"
    t.integer "position"
    t.bigint "query_id"
    t.datetime "updated_at", null: false
    t.index ["dashboard_id"], name: "index_blazer_dashboard_queries_on_dashboard_id"
    t.index ["query_id"], name: "index_blazer_dashboard_queries_on_query_id"
  end

  create_table "blazer_dashboards", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.bigint "creator_id"
    t.string "name"
    t.datetime "updated_at", null: false
    t.index ["creator_id"], name: "index_blazer_dashboards_on_creator_id"
  end

  create_table "blazer_queries", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.bigint "creator_id"
    t.string "data_source"
    t.text "description"
    t.string "name"
    t.text "statement"
    t.datetime "updated_at", null: false
    t.index ["creator_id"], name: "index_blazer_queries_on_creator_id"
  end

  create_table "canonical_event_mappings", force: :cascade do |t|
    t.bigint "canonical_transaction_id", null: false
    t.datetime "created_at", null: false
    t.bigint "event_id", null: false
    t.bigint "subledger_id"
    t.datetime "updated_at", null: false
    t.bigint "user_id"
    t.index ["canonical_transaction_id"], name: "index_canonical_event_mappings_on_canonical_transaction_id"
    t.index ["event_id", "canonical_transaction_id"], name: "index_cem_event_id_canonical_transaction_id_uniqueness", unique: true
    t.index ["event_id"], name: "index_canonical_event_mappings_on_event_id"
    t.index ["subledger_id"], name: "index_canonical_event_mappings_on_subledger_id"
    t.index ["user_id"], name: "index_canonical_event_mappings_on_user_id"
  end

  create_table "canonical_hashed_mappings", force: :cascade do |t|
    t.bigint "canonical_transaction_id", null: false
    t.datetime "created_at", null: false
    t.bigint "hashed_transaction_id", null: false
    t.datetime "updated_at", null: false
    t.index ["canonical_transaction_id"], name: "index_canonical_hashed_mappings_on_canonical_transaction_id"
    t.index ["hashed_transaction_id"], name: "index_canonical_hashed_mappings_on_hashed_transaction_id"
  end

  create_table "canonical_pending_declined_mappings", force: :cascade do |t|
    t.bigint "canonical_pending_transaction_id", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["canonical_pending_transaction_id"], name: "index_canonical_pending_declined_mappings_on_cpt_id", unique: true
  end

  create_table "canonical_pending_event_mappings", force: :cascade do |t|
    t.bigint "canonical_pending_transaction_id", null: false
    t.datetime "created_at", null: false
    t.bigint "event_id", null: false
    t.bigint "subledger_id"
    t.datetime "updated_at", null: false
    t.index ["canonical_pending_transaction_id"], name: "index_canonical_pending_event_map_on_canonical_pending_tx_id"
    t.index ["event_id"], name: "index_canonical_pending_event_mappings_on_event_id"
    t.index ["subledger_id"], name: "index_canonical_pending_event_mappings_on_subledger_id"
  end

  create_table "canonical_pending_settled_mappings", force: :cascade do |t|
    t.bigint "canonical_pending_transaction_id", null: false
    t.bigint "canonical_transaction_id", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["canonical_pending_transaction_id"], name: "index_canonical_pending_settled_map_on_canonical_pending_tx_id"
    t.index ["canonical_transaction_id"], name: "index_canonical_pending_settled_mappings_on_canonical_tx_id"
  end

  create_table "canonical_pending_transactions", force: :cascade do |t|
    t.integer "amount_cents", null: false
    t.bigint "check_deposit_id"
    t.datetime "created_at", null: false
    t.text "custom_memo"
    t.date "date", null: false
    t.boolean "fee_waived", default: false
    t.boolean "fronted", default: false
    t.text "hcb_code"
    t.bigint "increase_check_id"
    t.text "memo", null: false
    t.bigint "paypal_transfer_id"
    t.bigint "raw_pending_bank_fee_transaction_id"
    t.bigint "raw_pending_column_transaction_id"
    t.bigint "raw_pending_donation_transaction_id"
    t.bigint "raw_pending_incoming_disbursement_transaction_id"
    t.bigint "raw_pending_invoice_transaction_id"
    t.bigint "raw_pending_outgoing_ach_transaction_id"
    t.bigint "raw_pending_outgoing_check_transaction_id"
    t.bigint "raw_pending_outgoing_disbursement_transaction_id"
    t.bigint "raw_pending_stripe_transaction_id"
    t.bigint "reimbursement_expense_payout_id"
    t.bigint "reimbursement_payout_holding_id"
    t.datetime "updated_at", null: false
    t.bigint "wire_id"
    t.bigint "wise_transfer_id"
    t.index ["check_deposit_id"], name: "index_canonical_pending_transactions_on_check_deposit_id"
    t.index ["hcb_code"], name: "index_canonical_pending_transactions_on_hcb_code"
    t.index ["increase_check_id"], name: "index_canonical_pending_transactions_on_increase_check_id"
    t.index ["paypal_transfer_id"], name: "index_canonical_pending_transactions_on_paypal_transfer_id"
    t.index ["raw_pending_bank_fee_transaction_id"], name: "index_canonical_pending_txs_on_raw_pending_bank_fee_tx_id"
    t.index ["raw_pending_column_transaction_id"], name: "idx_on_raw_pending_column_transaction_id_ceea9a99e1", unique: true
    t.index ["raw_pending_column_transaction_id"], name: "index_canonical_pending_txs_on_rpct_id"
    t.index ["raw_pending_donation_transaction_id"], name: "index_canonical_pending_txs_on_raw_pending_donation_tx_id"
    t.index ["raw_pending_incoming_disbursement_transaction_id"], name: "index_cpts_on_raw_pending_incoming_disbursement_transaction_id"
    t.index ["raw_pending_invoice_transaction_id"], name: "index_canonical_pending_txs_on_raw_pending_invoice_tx_id"
    t.index ["raw_pending_outgoing_ach_transaction_id"], name: "index_canonical_pending_txs_on_raw_pending_outgoing_ach_tx_id"
    t.index ["raw_pending_outgoing_check_transaction_id"], name: "index_canonical_pending_txs_on_raw_pending_outgoing_check_tx_id"
    t.index ["raw_pending_outgoing_disbursement_transaction_id"], name: "index_cpts_on_raw_pending_outgoing_disbursement_transaction_id"
    t.index ["raw_pending_stripe_transaction_id"], name: "index_canonical_pending_txs_on_raw_pending_stripe_tx_id"
    t.index ["reimbursement_expense_payout_id"], name: "index_canonical_pending_txs_on_reimbursement_expense_payout_id"
    t.index ["reimbursement_payout_holding_id"], name: "index_canonical_pending_txs_on_reimbursement_payout_holding_id"
    t.index ["wire_id"], name: "index_canonical_pending_transactions_on_wire_id"
    t.index ["wise_transfer_id"], name: "index_canonical_pending_transactions_on_wise_transfer_id"
    t.check_constraint "fronted IS NOT NULL", name: "canonical_pending_transactions_fronted_null"
  end

  create_table "canonical_transactions", force: :cascade do |t|
    t.integer "amount_cents", null: false
    t.datetime "created_at", null: false
    t.text "custom_memo"
    t.date "date", null: false
    t.text "friendly_memo"
    t.text "hcb_code"
    t.text "memo", null: false
    t.bigint "transaction_source_id"
    t.string "transaction_source_type"
    t.datetime "updated_at", null: false
    t.index ["date"], name: "index_canonical_transactions_on_date"
    t.index ["hcb_code"], name: "index_canonical_transactions_on_hcb_code"
    t.index ["transaction_source_type", "transaction_source_id"], name: "index_canonical_transactions_on_transaction_source"
  end

  create_table "card_grant_pre_authorizations", force: :cascade do |t|
    t.string "aasm_state", null: false
    t.bigint "card_grant_id", null: false
    t.datetime "created_at", null: false
    t.integer "extracted_fraud_rating"
    t.string "extracted_merchant_name"
    t.text "extracted_product_description"
    t.string "extracted_product_name"
    t.integer "extracted_product_price_cents"
    t.integer "extracted_total_price_cents"
    t.boolean "extracted_valid_purchase"
    t.text "extracted_validity_reasoning"
    t.string "product_url"
    t.datetime "updated_at", null: false
    t.index ["card_grant_id"], name: "index_card_grant_pre_authorizations_on_card_grant_id"
  end

  create_table "card_grant_settings", force: :cascade do |t|
    t.string "banned_categories"
    t.string "banned_merchants"
    t.boolean "block_suspected_fraud", default: true, null: false
    t.string "category_lock"
    t.bigint "event_id", null: false
    t.integer "expiration_preference", default: 365, null: false
    t.string "invite_message"
    t.string "keyword_lock"
    t.string "merchant_lock"
    t.boolean "pre_authorization_required", default: false, null: false
    t.boolean "reimbursement_conversions_enabled", default: true, null: false
    t.string "support_message"
    t.string "support_url"
    t.index ["event_id"], name: "index_card_grant_settings_on_event_id", unique: true
  end

  create_table "card_grants", force: :cascade do |t|
    t.integer "amount_cents"
    t.string "banned_categories"
    t.string "banned_merchants"
    t.string "category_lock"
    t.datetime "created_at", null: false
    t.bigint "disbursement_id"
    t.string "email", null: false
    t.bigint "event_id", null: false
    t.text "instructions"
    t.string "invite_message"
    t.string "keyword_lock"
    t.string "merchant_lock"
    t.boolean "one_time_use"
    t.boolean "pre_authorization_required", default: false, null: false
    t.string "purpose"
    t.bigint "sent_by_id", null: false
    t.integer "status", default: 0, null: false
    t.bigint "stripe_card_id"
    t.bigint "subledger_id"
    t.datetime "updated_at", null: false
    t.bigint "user_id", null: false
    t.index ["disbursement_id"], name: "index_card_grants_on_disbursement_id"
    t.index ["event_id"], name: "index_card_grants_on_event_id"
    t.index ["sent_by_id"], name: "index_card_grants_on_sent_by_id"
    t.index ["stripe_card_id"], name: "index_card_grants_on_stripe_card_id"
    t.index ["subledger_id"], name: "index_card_grants_on_subledger_id"
    t.index ["user_id"], name: "index_card_grants_on_user_id"
  end

  create_table "check_deposits", force: :cascade do |t|
    t.integer "amount_cents"
    t.string "back_file_id"
    t.string "column_id"
    t.datetime "created_at", null: false
    t.bigint "created_by_id", null: false
    t.bigint "event_id", null: false
    t.string "front_file_id"
    t.string "increase_id"
    t.string "increase_status"
    t.string "rejection_reason"
    t.datetime "updated_at", null: false
    t.index ["created_by_id"], name: "index_check_deposits_on_created_by_id"
    t.index ["event_id"], name: "index_check_deposits_on_event_id"
    t.index ["increase_id"], name: "index_check_deposits_on_increase_id", unique: true
  end

  create_table "checks", force: :cascade do |t|
    t.string "aasm_state"
    t.integer "amount"
    t.datetime "approved_at", precision: nil
    t.integer "check_number"
    t.datetime "created_at", precision: nil, null: false
    t.bigint "creator_id"
    t.text "description_ciphertext"
    t.datetime "expected_delivery_date", precision: nil
    t.datetime "exported_at", precision: nil
    t.bigint "lob_address_id"
    t.string "lob_id"
    t.text "lob_url"
    t.text "memo"
    t.text "payment_for"
    t.datetime "refunded_at", precision: nil
    t.datetime "rejected_at", precision: nil
    t.datetime "send_date", precision: nil
    t.string "transaction_memo"
    t.datetime "updated_at", precision: nil, null: false
    t.datetime "voided_at", precision: nil
    t.index ["creator_id"], name: "index_checks_on_creator_id"
    t.index ["lob_address_id"], name: "index_checks_on_lob_address_id"
  end

  create_table "column_account_numbers", force: :cascade do |t|
    t.string "account_number_bidx"
    t.text "account_number_ciphertext"
    t.text "bic_code_ciphertext"
    t.text "column_id"
    t.datetime "created_at", null: false
    t.boolean "deposit_only", default: true, null: false
    t.bigint "event_id", null: false
    t.text "routing_number_ciphertext"
    t.datetime "updated_at", null: false
    t.index ["account_number_bidx"], name: "index_column_account_numbers_on_account_number_bidx", unique: true
    t.index ["event_id"], name: "index_column_account_numbers_on_event_id", unique: true
  end

  create_table "column_statements", force: :cascade do |t|
    t.integer "closing_balance"
    t.datetime "created_at", null: false
    t.datetime "end_date"
    t.datetime "start_date"
    t.integer "starting_balance"
    t.datetime "updated_at", null: false
  end

  create_table "comment_reactions", force: :cascade do |t|
    t.bigint "comment_id", null: false
    t.datetime "created_at", null: false
    t.string "emoji", null: false
    t.bigint "reactor_id", null: false
    t.datetime "updated_at", null: false
    t.index ["comment_id"], name: "index_comment_reactions_on_comment_id"
    t.index ["emoji"], name: "index_comment_reactions_on_emoji"
    t.index ["reactor_id"], name: "index_comment_reactions_on_reactor_id"
  end

  create_table "comments", force: :cascade do |t|
    t.integer "action", default: 0, null: false
    t.boolean "admin_only", default: false, null: false
    t.bigint "commentable_id"
    t.string "commentable_type"
    t.text "content_ciphertext"
    t.datetime "created_at", precision: nil, null: false
    t.datetime "deleted_at"
    t.boolean "has_untracked_edit", default: false, null: false
    t.datetime "updated_at", precision: nil, null: false
    t.bigint "user_id"
    t.index ["commentable_id", "commentable_type"], name: "index_comments_on_commentable_id_and_commentable_type"
    t.index ["commentable_type", "commentable_id"], name: "index_comments_on_commentable_type_and_commentable_id"
    t.index ["user_id"], name: "index_comments_on_user_id"
  end

  create_table "console1984_commands", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.bigint "sensitive_access_id"
    t.bigint "session_id", null: false
    t.text "statements"
    t.datetime "updated_at", null: false
    t.index ["sensitive_access_id"], name: "index_console1984_commands_on_sensitive_access_id"
    t.index ["session_id", "created_at", "sensitive_access_id"], name: "on_session_and_sensitive_chronologically"
  end

  create_table "console1984_sensitive_accesses", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.text "justification"
    t.bigint "session_id", null: false
    t.datetime "updated_at", null: false
    t.index ["session_id"], name: "index_console1984_sensitive_accesses_on_session_id"
  end

  create_table "console1984_sessions", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.text "reason"
    t.datetime "updated_at", null: false
    t.bigint "user_id", null: false
    t.index ["created_at"], name: "index_console1984_sessions_on_created_at"
    t.index ["user_id", "created_at"], name: "index_console1984_sessions_on_user_id_and_created_at"
  end

  create_table "console1984_users", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.string "username", null: false
    t.index ["username"], name: "index_console1984_users_on_username"
  end

  create_table "contract_parties", force: :cascade do |t|
    t.string "aasm_state"
    t.bigint "contract_id", null: false
    t.datetime "created_at", null: false
    t.datetime "deleted_at"
    t.string "external_email"
    t.string "external_id"
    t.string "role", null: false
    t.datetime "signed_at"
    t.datetime "updated_at", null: false
    t.bigint "user_id"
    t.index ["contract_id"], name: "index_contract_parties_on_contract_id"
    t.index ["user_id"], name: "index_contract_parties_on_user_id"
  end

  create_table "contracts", force: :cascade do |t|
    t.string "aasm_state", null: false
    t.bigint "contractable_id"
    t.string "contractable_type"
    t.string "cosigner_email"
    t.datetime "created_at", null: false
    t.datetime "deleted_at", precision: nil
    t.bigint "document_id"
    t.string "external_id"
    t.integer "external_service"
    t.string "external_template_id"
    t.boolean "include_videos"
    t.jsonb "prefills"
    t.datetime "signed_at"
    t.string "type", null: false
    t.datetime "updated_at", null: false
    t.datetime "void_at"
    t.index ["contractable_type", "contractable_id"], name: "index_contracts_on_contractable"
    t.index ["document_id"], name: "index_contracts_on_document_id"
  end

  create_table "disbursements", force: :cascade do |t|
    t.string "aasm_state"
    t.integer "amount"
    t.datetime "created_at", precision: nil, null: false
    t.datetime "deposited_at", precision: nil
    t.bigint "destination_subledger_id"
    t.bigint "destination_transaction_category_id"
    t.datetime "errored_at", precision: nil
    t.bigint "event_id"
    t.bigint "fulfilled_by_id"
    t.datetime "in_transit_at", precision: nil
    t.string "name"
    t.datetime "pending_at", precision: nil
    t.datetime "rejected_at", precision: nil
    t.bigint "requested_by_id"
    t.date "scheduled_on"
    t.boolean "should_charge_fee", default: false
    t.bigint "source_event_id"
    t.bigint "source_subledger_id"
    t.bigint "source_transaction_category_id"
    t.datetime "updated_at", precision: nil, null: false
    t.index ["destination_subledger_id"], name: "index_disbursements_on_destination_subledger_id"
    t.index ["destination_transaction_category_id"], name: "index_disbursements_on_destination_transaction_category_id"
    t.index ["event_id"], name: "index_disbursements_on_event_id"
    t.index ["fulfilled_by_id"], name: "index_disbursements_on_fulfilled_by_id"
    t.index ["requested_by_id"], name: "index_disbursements_on_requested_by_id"
    t.index ["source_event_id"], name: "index_disbursements_on_source_event_id"
    t.index ["source_subledger_id"], name: "index_disbursements_on_source_subledger_id"
    t.index ["source_transaction_category_id"], name: "index_disbursements_on_source_transaction_category_id"
  end

  create_table "discord_messages", force: :cascade do |t|
    t.bigint "activity_id"
    t.datetime "created_at", null: false
    t.string "discord_channel_id", null: false
    t.string "discord_guild_id", null: false
    t.string "discord_message_id", null: false
    t.datetime "updated_at", null: false
    t.index ["activity_id"], name: "index_discord_messages_on_activity_id"
    t.index ["discord_message_id"], name: "index_discord_messages_on_discord_message_id", unique: true
  end

  create_table "document_downloads", force: :cascade do |t|
    t.datetime "created_at", precision: nil, null: false
    t.datetime "deleted_at", precision: nil
    t.bigint "document_id"
    t.inet "ip_address"
    t.datetime "updated_at", precision: nil, null: false
    t.text "user_agent"
    t.bigint "user_id"
    t.index ["document_id"], name: "index_document_downloads_on_document_id"
    t.index ["user_id"], name: "index_document_downloads_on_user_id"
  end

  create_table "documents", force: :cascade do |t|
    t.string "aasm_state"
    t.datetime "archived_at"
    t.bigint "archived_by_id"
    t.integer "category", default: 0, null: false
    t.datetime "created_at", precision: nil, null: false
    t.datetime "deleted_at", precision: nil
    t.bigint "event_id"
    t.text "name"
    t.text "slug"
    t.datetime "updated_at", precision: nil, null: false
    t.bigint "user_id"
    t.index ["archived_by_id"], name: "index_documents_on_archived_by_id"
    t.index ["event_id"], name: "index_documents_on_event_id"
    t.index ["slug"], name: "index_documents_on_slug", unique: true
    t.index ["user_id"], name: "index_documents_on_user_id"
  end

  create_table "donation_goals", force: :cascade do |t|
    t.integer "amount_cents", null: false
    t.datetime "created_at", null: false
    t.datetime "deleted_at", precision: nil
    t.bigint "event_id", null: false
    t.datetime "tracking_since", precision: nil, null: false
    t.datetime "updated_at", null: false
    t.index ["event_id"], name: "index_donation_goals_on_event_id"
  end

  create_table "donation_payouts", force: :cascade do |t|
    t.bigint "amount"
    t.datetime "arrival_date", precision: nil
    t.boolean "automatic"
    t.datetime "created_at", precision: nil, null: false
    t.text "currency"
    t.text "description"
    t.text "failure_code"
    t.text "failure_message"
    t.text "failure_stripe_balance_transaction_id"
    t.text "method"
    t.text "source_type"
    t.text "statement_descriptor"
    t.text "status"
    t.text "stripe_balance_transaction_id"
    t.datetime "stripe_created_at", precision: nil
    t.text "stripe_destination_id"
    t.text "stripe_payout_id"
    t.text "type"
    t.datetime "updated_at", precision: nil, null: false
    t.index ["failure_stripe_balance_transaction_id"], name: "index_donation_payouts_on_failure_stripe_balance_transaction_id", unique: true
    t.index ["stripe_balance_transaction_id"], name: "index_donation_payouts_on_stripe_balance_transaction_id", unique: true
    t.index ["stripe_payout_id"], name: "index_donation_payouts_on_stripe_payout_id", unique: true
  end

  create_table "donation_tiers", force: :cascade do |t|
    t.integer "amount_cents", null: false
    t.datetime "created_at", null: false
    t.datetime "deleted_at"
    t.text "description"
    t.bigint "event_id", null: false
    t.string "name", null: false
    t.integer "sort_index"
    t.datetime "updated_at", null: false
    t.index ["event_id"], name: "index_donation_tiers_on_event_id"
  end

  create_table "donations", force: :cascade do |t|
    t.string "aasm_state"
    t.integer "amount"
    t.integer "amount_received"
    t.boolean "anonymous", default: false, null: false
    t.bigint "collected_by_id"
    t.datetime "created_at", precision: nil, null: false
    t.text "email"
    t.bigint "event_id"
    t.boolean "fee_covered", default: false, null: false
    t.bigint "fee_reimbursement_id"
    t.text "hcb_code"
    t.boolean "in_person", default: false
    t.datetime "in_transit_at"
    t.inet "ip_address"
    t.text "message"
    t.text "name"
    t.datetime "payout_creation_balance_available_at", precision: nil
    t.integer "payout_creation_balance_net"
    t.integer "payout_creation_balance_stripe_fee"
    t.datetime "payout_creation_queued_at", precision: nil
    t.datetime "payout_creation_queued_for", precision: nil
    t.string "payout_creation_queued_job_id"
    t.bigint "payout_id"
    t.bigint "recurring_donation_id"
    t.text "referrer"
    t.string "status"
    t.string "stripe_client_secret"
    t.string "stripe_payment_intent_id"
    t.boolean "tax_deductible", default: true, null: false
    t.datetime "updated_at", precision: nil, null: false
    t.string "url_hash"
    t.text "user_agent"
    t.text "utm_campaign"
    t.text "utm_content"
    t.text "utm_medium"
    t.text "utm_source"
    t.text "utm_term"
    t.index ["event_id"], name: "index_donations_on_event_id"
    t.index ["fee_reimbursement_id"], name: "index_donations_on_fee_reimbursement_id"
    t.index ["payout_id"], name: "index_donations_on_payout_id"
    t.index ["recurring_donation_id"], name: "index_donations_on_recurring_donation_id"
  end

  create_table "emburse_card_requests", force: :cascade do |t|
    t.datetime "accepted_at", precision: nil
    t.datetime "canceled_at", precision: nil
    t.datetime "created_at", precision: nil, null: false
    t.bigint "creator_id"
    t.bigint "daily_limit"
    t.bigint "emburse_card_id"
    t.bigint "event_id"
    t.datetime "fulfilled_at", precision: nil
    t.bigint "fulfilled_by_id"
    t.string "full_name"
    t.boolean "is_virtual"
    t.text "notes"
    t.datetime "rejected_at", precision: nil
    t.text "shipping_address"
    t.string "shipping_address_city"
    t.string "shipping_address_state"
    t.string "shipping_address_street_one"
    t.string "shipping_address_street_two"
    t.string "shipping_address_zip"
    t.datetime "updated_at", precision: nil, null: false
    t.index ["creator_id"], name: "index_emburse_card_requests_on_creator_id"
    t.index ["emburse_card_id"], name: "index_emburse_card_requests_on_emburse_card_id"
    t.index ["event_id"], name: "index_emburse_card_requests_on_event_id"
    t.index ["fulfilled_by_id"], name: "index_emburse_card_requests_on_fulfilled_by_id"
  end

  create_table "emburse_cards", force: :cascade do |t|
    t.text "address"
    t.datetime "created_at", precision: nil, null: false
    t.bigint "daily_limit"
    t.datetime "deactivated_at", precision: nil
    t.text "emburse_id"
    t.string "emburse_state"
    t.bigint "event_id"
    t.integer "expiration_month"
    t.integer "expiration_year"
    t.string "full_name"
    t.boolean "is_virtual"
    t.string "last_four"
    t.text "slug"
    t.datetime "updated_at", precision: nil, null: false
    t.bigint "user_id"
    t.index ["event_id"], name: "index_emburse_cards_on_event_id"
    t.index ["slug"], name: "index_emburse_cards_on_slug", unique: true
    t.index ["user_id"], name: "index_emburse_cards_on_user_id"
  end

  create_table "emburse_transactions", force: :cascade do |t|
    t.integer "amount"
    t.text "category_code"
    t.text "category_emburse_id"
    t.text "category_name"
    t.text "category_parent"
    t.text "category_url"
    t.datetime "created_at", precision: nil, null: false
    t.datetime "deleted_at", precision: nil
    t.bigint "emburse_card_id"
    t.string "emburse_card_uuid"
    t.string "emburse_department_id"
    t.string "emburse_id"
    t.bigint "event_id"
    t.text "label"
    t.text "location"
    t.datetime "marked_no_or_lost_receipt_at", precision: nil
    t.text "merchant_address"
    t.text "merchant_city"
    t.integer "merchant_mcc"
    t.bigint "merchant_mid"
    t.text "merchant_name"
    t.text "merchant_state"
    t.text "merchant_zip"
    t.text "note"
    t.datetime "notified_admin_at", precision: nil
    t.text "receipt_filename"
    t.text "receipt_url"
    t.integer "state"
    t.datetime "transaction_time", precision: nil
    t.datetime "updated_at", precision: nil, null: false
    t.index ["deleted_at"], name: "index_emburse_transactions_on_deleted_at"
    t.index ["emburse_card_id"], name: "index_emburse_transactions_on_emburse_card_id"
    t.index ["event_id"], name: "index_emburse_transactions_on_event_id"
  end

  create_table "emburse_transfers", force: :cascade do |t|
    t.datetime "accepted_at", precision: nil
    t.datetime "canceled_at", precision: nil
    t.datetime "created_at", precision: nil, null: false
    t.bigint "creator_id"
    t.bigint "emburse_card_id"
    t.string "emburse_transaction_id"
    t.bigint "event_id"
    t.bigint "fulfilled_by_id"
    t.bigint "load_amount"
    t.datetime "rejected_at", precision: nil
    t.datetime "updated_at", precision: nil, null: false
    t.index ["creator_id"], name: "index_emburse_transfers_on_creator_id"
    t.index ["emburse_card_id"], name: "index_emburse_transfers_on_emburse_card_id"
    t.index ["event_id"], name: "index_emburse_transfers_on_event_id"
    t.index ["fulfilled_by_id"], name: "index_emburse_transfers_on_fulfilled_by_id"
  end

  create_table "employee_payments", force: :cascade do |t|
    t.string "aasm_state"
    t.integer "amount_cents", default: 0, null: false
    t.datetime "approved_at"
    t.datetime "created_at", null: false
    t.text "description"
    t.bigint "employee_id", null: false
    t.bigint "payout_id"
    t.string "payout_type"
    t.datetime "rejected_at"
    t.text "review_message"
    t.bigint "reviewed_by_id"
    t.text "title", null: false
    t.datetime "updated_at", null: false
    t.index ["employee_id"], name: "index_employee_payments_on_employee_id"
    t.index ["reviewed_by_id"], name: "index_employee_payments_on_reviewed_by_id"
  end

  create_table "employees", force: :cascade do |t|
    t.string "aasm_state"
    t.datetime "created_at", null: false
    t.datetime "deleted_at"
    t.bigint "entity_id", null: false
    t.string "entity_type", null: false
    t.bigint "event_id", null: false
    t.string "gusto_id"
    t.datetime "updated_at", null: false
    t.index ["event_id"], name: "index_employees_on_event_id"
  end

  create_table "event_affiliations", force: :cascade do |t|
    t.bigint "affiliable_id", null: false
    t.string "affiliable_type", null: false
    t.datetime "created_at", null: false
    t.bigint "event_id", null: false
    t.jsonb "metadata", null: false
    t.string "name", null: false
    t.datetime "updated_at", null: false
    t.index ["affiliable_type", "affiliable_id"], name: "index_event_affiliations_on_affiliable"
    t.index ["event_id"], name: "index_event_affiliations_on_event_id"
  end

  create_table "event_configurations", force: :cascade do |t|
    t.boolean "anonymous_donations", default: false
    t.string "contact_email"
    t.boolean "cover_donation_fees", default: false
    t.datetime "created_at", null: false
    t.bigint "event_id", null: false
    t.boolean "generate_monthly_announcement", default: false, null: false
    t.string "subevent_plan"
    t.datetime "updated_at", null: false
    t.index ["event_id"], name: "index_event_configurations_on_event_id", unique: true
  end

  create_table "event_follows", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.bigint "event_id", null: false
    t.datetime "updated_at", null: false
    t.bigint "user_id", null: false
    t.index ["event_id"], name: "index_event_follows_on_event_id"
    t.index ["user_id", "event_id"], name: "index_event_follows_on_user_id_and_event_id", unique: true
  end

  create_table "event_group_memberships", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.bigint "event_group_id", null: false
    t.bigint "event_id", null: false
    t.datetime "updated_at", null: false
    t.index ["event_group_id"], name: "index_event_group_memberships_on_event_group_id"
    t.index ["event_id", "event_group_id"], name: "index_event_group_memberships_on_event_id_and_event_group_id", unique: true
  end

  create_table "event_groups", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.citext "name", null: false
    t.datetime "updated_at", null: false
    t.bigint "user_id", null: false
    t.index ["name"], name: "index_event_groups_on_name", unique: true
    t.index ["user_id"], name: "index_event_groups_on_user_id"
  end

  create_table "event_plans", force: :cascade do |t|
    t.string "aasm_state"
    t.datetime "created_at", null: false
    t.bigint "event_id", null: false
    t.datetime "inactive_at"
    t.string "type"
    t.datetime "updated_at", null: false
    t.index ["event_id"], name: "index_event_plans_on_event_id"
  end

  create_table "event_scoped_tags", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.string "name", null: false
    t.bigint "parent_event_id", null: false
    t.datetime "updated_at", null: false
    t.index ["parent_event_id"], name: "index_event_scoped_tags_on_parent_event_id"
  end

  create_table "event_scoped_tags_events", id: false, force: :cascade do |t|
    t.datetime "created_at", null: false
    t.bigint "event_id", null: false
    t.bigint "event_scoped_tag_id", null: false
    t.datetime "updated_at", null: false
    t.index ["event_id"], name: "index_event_scoped_tags_events_on_event_id"
    t.index ["event_scoped_tag_id", "event_id"], name: "idx_on_event_scoped_tag_id_event_id_4b716d1ac0", unique: true
    t.index ["event_scoped_tag_id"], name: "index_event_scoped_tags_events_on_event_scoped_tag_id"
  end

  create_table "event_tags", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.string "description"
    t.string "name", null: false
    t.string "purpose"
    t.datetime "updated_at", null: false
    t.index ["name", "purpose"], name: "index_event_tags_on_name_and_purpose", unique: true
  end

  create_table "event_tags_events", id: false, force: :cascade do |t|
    t.bigint "event_id", null: false
    t.bigint "event_tag_id", null: false
    t.index ["event_id"], name: "index_event_tags_events_on_event_id"
    t.index ["event_tag_id", "event_id"], name: "index_event_tags_events_on_event_tag_id_and_event_id", unique: true
    t.index ["event_tag_id"], name: "index_event_tags_events_on_event_tag_id"
  end

  create_table "events", force: :cascade do |t|
    t.string "aasm_state"
    t.datetime "activated_at"
    t.text "address"
    t.boolean "can_front_balance", default: true, null: false
    t.integer "country"
    t.datetime "created_at", precision: nil, null: false
    t.datetime "deleted_at", precision: nil
    t.boolean "demo_mode", default: false, null: false
    t.datetime "demo_mode_request_meeting_at", precision: nil
    t.text "description"
    t.string "discord_channel_id"
    t.string "discord_guild_id"
    t.boolean "donation_page_enabled", default: true
    t.text "donation_page_message"
    t.text "donation_reply_to_email"
    t.text "donation_thank_you_message"
    t.boolean "donation_tiers_enabled", default: false, null: false
    t.string "emburse_department_id"
    t.boolean "fee_waiver_applied", default: false, null: false
    t.boolean "fee_waiver_eligible", default: false, null: false
    t.boolean "financially_frozen", default: false, null: false
    t.datetime "hidden_at", precision: nil
    t.boolean "holiday_features", default: true, null: false
    t.string "increase_account_id", null: false
    t.boolean "is_indexable", default: true
    t.boolean "is_public", default: true
    t.datetime "last_fee_processed_at", precision: nil
    t.text "name", null: false
    t.bigint "parent_id"
    t.bigint "point_of_contact_id"
    t.string "postal_code"
    t.text "public_message"
    t.boolean "public_reimbursement_page_enabled", default: false, null: false
    t.text "public_reimbursement_page_message"
    t.boolean "reimbursements_require_organizer_peer_review", default: false, null: false
    t.integer "risk_level"
    t.string "short_name"
    t.text "slug"
    t.integer "stripe_card_shipping_type", default: 0, null: false
    t.datetime "updated_at", precision: nil, null: false
    t.string "website"
    t.index ["discord_channel_id"], name: "index_events_on_discord_channel_id", unique: true
    t.index ["discord_guild_id"], name: "index_events_on_discord_guild_id", unique: true
    t.index ["parent_id"], name: "index_events_on_parent_id"
    t.index ["point_of_contact_id"], name: "index_events_on_point_of_contact_id"
  end

  create_table "exports", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.jsonb "parameters"
    t.bigint "requested_by_id"
    t.text "type"
    t.datetime "updated_at", null: false
    t.index ["requested_by_id"], name: "index_exports_on_requested_by_id"
  end

  create_table "fee_reimbursements", force: :cascade do |t|
    t.bigint "amount"
    t.datetime "created_at", precision: nil, null: false
    t.datetime "processed_at", precision: nil
    t.bigint "stripe_topup_id"
    t.string "transaction_memo"
    t.datetime "updated_at", precision: nil, null: false
    t.index ["stripe_topup_id"], name: "index_fee_reimbursements_on_stripe_topup_id"
    t.index ["transaction_memo"], name: "index_fee_reimbursements_on_transaction_memo", unique: true
  end

  create_table "fee_relationships", force: :cascade do |t|
    t.datetime "created_at", precision: nil, null: false
    t.bigint "event_id"
    t.bigint "fee_amount"
    t.boolean "fee_applies"
    t.boolean "is_fee_payment"
    t.datetime "updated_at", precision: nil, null: false
    t.index ["event_id"], name: "index_fee_relationships_on_event_id"
  end

  create_table "fee_revenues", force: :cascade do |t|
    t.string "aasm_state"
    t.integer "amount_cents"
    t.datetime "created_at", null: false
    t.date "end"
    t.date "start"
    t.datetime "updated_at", null: false
  end

  create_table "fees", force: :cascade do |t|
    t.decimal "amount_cents_as_decimal"
    t.bigint "canonical_event_mapping_id"
    t.datetime "created_at", null: false
    t.bigint "event_id"
    t.decimal "event_sponsorship_fee"
    t.string "memo"
    t.text "reason"
    t.datetime "updated_at", null: false
    t.index ["canonical_event_mapping_id"], name: "index_fees_on_canonical_event_mapping_id"
    t.index ["event_id"], name: "index_fees_on_event_id"
  end

  create_table "flipper_features", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.string "key", null: false
    t.datetime "updated_at", null: false
    t.index ["key"], name: "index_flipper_features_on_key", unique: true
  end

  create_table "flipper_gates", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.string "feature_key", null: false
    t.string "key", null: false
    t.datetime "updated_at", null: false
    t.text "value"
    t.index ["feature_key", "key", "value"], name: "index_flipper_gates_on_feature_key_and_key_and_value", unique: true
  end

  create_table "friendly_id_slugs", id: :serial, force: :cascade do |t|
    t.datetime "created_at", precision: nil
    t.string "scope"
    t.string "slug", null: false
    t.integer "sluggable_id", null: false
    t.string "sluggable_type", limit: 50
    t.index ["slug", "sluggable_type", "scope"], name: "index_friendly_id_slugs_on_slug_and_sluggable_type_and_scope", unique: true
    t.index ["slug", "sluggable_type"], name: "index_friendly_id_slugs_on_slug_and_sluggable_type"
    t.index ["sluggable_id"], name: "index_friendly_id_slugs_on_sluggable_id"
    t.index ["sluggable_type"], name: "index_friendly_id_slugs_on_sluggable_type"
  end

  create_table "g_suite_accounts", force: :cascade do |t|
    t.datetime "accepted_at", precision: nil
    t.text "address"
    t.text "backup_email"
    t.datetime "created_at", precision: nil, null: false
    t.bigint "creator_id"
    t.string "first_name"
    t.bigint "g_suite_id"
    t.text "initial_password_ciphertext"
    t.string "last_name"
    t.datetime "suspended_at", precision: nil
    t.datetime "updated_at", precision: nil, null: false
    t.index ["creator_id"], name: "index_g_suite_accounts_on_creator_id"
    t.index ["g_suite_id"], name: "index_g_suite_accounts_on_g_suite_id"
  end

  create_table "g_suite_aliases", force: :cascade do |t|
    t.text "address"
    t.datetime "created_at", null: false
    t.bigint "g_suite_account_id", null: false
    t.datetime "updated_at", null: false
    t.index ["g_suite_account_id"], name: "index_g_suite_aliases_on_g_suite_account_id"
  end

  create_table "g_suite_revocations", force: :cascade do |t|
    t.string "aasm_state"
    t.datetime "created_at", null: false
    t.datetime "deleted_at"
    t.bigint "g_suite_id", null: false
    t.boolean "one_week_notice_sent", default: false, null: false
    t.text "other_reason"
    t.integer "reason", default: 0, null: false
    t.datetime "scheduled_at", null: false
    t.datetime "updated_at", null: false
    t.index ["g_suite_id"], name: "index_g_suite_revocations_on_g_suite_id"
  end

  create_table "g_suites", force: :cascade do |t|
    t.string "aasm_state", default: "creating"
    t.datetime "created_at", precision: nil, null: false
    t.bigint "created_by_id"
    t.datetime "deleted_at", precision: nil
    t.text "dkim_key"
    t.citext "domain"
    t.bigint "event_id"
    t.boolean "immune_to_revocation", default: false, null: false
    t.text "remote_org_unit_id"
    t.text "remote_org_unit_path"
    t.datetime "updated_at", precision: nil, null: false
    t.text "verification_key"
    t.index ["created_by_id"], name: "index_g_suites_on_created_by_id"
    t.index ["event_id"], name: "index_g_suites_on_event_id"
  end

  create_table "governance_admin_transfer_approval_attempts", force: :cascade do |t|
    t.integer "attempted_amount_cents", null: false
    t.datetime "created_at", null: false
    t.integer "current_limit_amount_cents", null: false
    t.integer "current_limit_remaining_amount_cents", null: false
    t.integer "current_limit_used_amount_cents", null: false
    t.datetime "current_limit_window_ended_at", null: false
    t.datetime "current_limit_window_started_at", null: false
    t.string "denial_reason"
    t.bigint "governance_admin_transfer_limit_id", null: false
    t.bigint "governance_request_context_id"
    t.string "result", null: false
    t.bigint "transfer_id", null: false
    t.string "transfer_type", null: false
    t.datetime "updated_at", null: false
    t.bigint "user_id", null: false
    t.index ["governance_admin_transfer_limit_id"], name: "idx_on_governance_admin_transfer_limit_id_3dfaba4d9a"
    t.index ["governance_request_context_id"], name: "idx_on_governance_request_context_id_bec1adb1c2"
    t.index ["transfer_type", "transfer_id"], name: "index_governance_admin_transfer_approval_attempts_on_transfer"
    t.index ["user_id"], name: "index_governance_admin_transfer_approval_attempts_on_user_id"
  end

  create_table "governance_admin_transfer_limits", force: :cascade do |t|
    t.integer "amount_cents", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.bigint "user_id", null: false
    t.index ["user_id"], name: "index_governance_admin_transfer_limits_on_user_id", unique: true
  end

  create_table "governance_request_contexts", force: :cascade do |t|
    t.string "action_name", null: false
    t.bigint "authentication_session_id", null: false
    t.string "authentication_session_type", null: false
    t.string "controller_name", null: false
    t.datetime "created_at", null: false
    t.string "http_method", null: false
    t.bigint "impersonator_id"
    t.inet "ip_address", null: false
    t.datetime "occurred_at", null: false
    t.string "path", null: false
    t.string "request_id", null: false
    t.datetime "updated_at", null: false
    t.string "user_agent", null: false
    t.bigint "user_id", null: false
    t.index ["authentication_session_type", "authentication_session_id"], name: "index_governance_request_contexts_on_authentication_session"
    t.index ["impersonator_id"], name: "index_governance_request_contexts_on_impersonator_id"
    t.index ["ip_address"], name: "index_governance_request_contexts_on_ip_address"
    t.index ["request_id"], name: "index_governance_request_contexts_on_request_id", unique: true
    t.index ["user_id"], name: "index_governance_request_contexts_on_user_id"
  end

  create_table "hashed_transactions", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.date "date"
    t.bigint "duplicate_of_hashed_transaction_id"
    t.text "primary_hash"
    t.text "primary_hash_input"
    t.bigint "raw_csv_transaction_id"
    t.bigint "raw_emburse_transaction_id"
    t.bigint "raw_increase_transaction_id"
    t.bigint "raw_plaid_transaction_id"
    t.bigint "raw_stripe_transaction_id"
    t.text "secondary_hash"
    t.text "unique_bank_identifier"
    t.datetime "updated_at", null: false
    t.index ["duplicate_of_hashed_transaction_id"], name: "index_hashed_transactions_on_duplicate_of_hashed_transaction_id"
    t.index ["raw_csv_transaction_id"], name: "index_hashed_transactions_on_raw_csv_transaction_id"
    t.index ["raw_increase_transaction_id"], name: "index_hashed_transactions_on_raw_increase_transaction_id"
    t.index ["raw_plaid_transaction_id"], name: "index_hashed_transactions_on_raw_plaid_transaction_id"
    t.index ["raw_stripe_transaction_id"], name: "index_hashed_transactions_on_raw_stripe_transaction_id"
  end

  create_table "hcb_code_personal_transactions", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.bigint "hcb_code_id"
    t.bigint "invoice_id"
    t.bigint "reporter_id"
    t.datetime "updated_at", null: false
    t.index ["hcb_code_id"], name: "index_hcb_code_personal_transactions_on_hcb_code_id", unique: true
    t.index ["invoice_id"], name: "index_hcb_code_personal_transactions_on_invoice_id"
    t.index ["reporter_id"], name: "index_hcb_code_personal_transactions_on_reporter_id"
  end

  create_table "hcb_code_pins", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.bigint "event_id"
    t.bigint "hcb_code_id"
    t.datetime "updated_at", null: false
    t.index ["event_id"], name: "index_hcb_code_pins_on_event_id"
    t.index ["hcb_code_id"], name: "index_hcb_code_pins_on_hcb_code_id"
  end

  create_table "hcb_code_tag_suggestions", force: :cascade do |t|
    t.string "aasm_state"
    t.datetime "created_at", null: false
    t.bigint "hcb_code_id", null: false
    t.bigint "tag_id", null: false
    t.datetime "updated_at", null: false
    t.index ["hcb_code_id"], name: "index_hcb_code_tag_suggestions_on_hcb_code_id"
    t.index ["tag_id"], name: "index_hcb_code_tag_suggestions_on_tag_id"
  end

  create_table "hcb_codes", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.bigint "event_id"
    t.text "hcb_code", null: false
    t.bigint "subledger_id"
    t.datetime "marked_no_or_lost_receipt_at", precision: nil
    t.text "short_code"
    t.datetime "updated_at", null: false
    t.index ["hcb_code"], name: "index_hcb_codes_on_hcb_code", unique: true
    t.check_constraint "short_code = upper(short_code)", name: "constraint_hcb_codes_on_short_code_to_uppercase"
  end

  create_table "hcb_codes_tags", id: false, force: :cascade do |t|
    t.datetime "created_at"
    t.bigint "hcb_code_id", null: false
    t.bigint "tag_id", null: false
    t.datetime "updated_at"
    t.index ["hcb_code_id", "tag_id"], name: "index_hcb_codes_tags_on_hcb_code_id_and_tag_id", unique: true
  end

  create_table "increase_account_numbers", force: :cascade do |t|
    t.text "account_number_ciphertext"
    t.datetime "created_at", null: false
    t.bigint "event_id", null: false
    t.string "increase_account_number_id"
    t.string "increase_limit_id"
    t.text "routing_number_ciphertext"
    t.datetime "updated_at", null: false
    t.index ["event_id"], name: "index_increase_account_numbers_on_event_id"
  end

  create_table "increase_checks", force: :cascade do |t|
    t.string "aasm_state"
    t.string "address_city"
    t.string "address_line1"
    t.string "address_line2"
    t.string "address_state"
    t.string "address_zip"
    t.integer "amount"
    t.datetime "approved_at"
    t.string "check_number"
    t.string "column_delivery_status"
    t.string "column_id"
    t.jsonb "column_object"
    t.string "column_status"
    t.datetime "created_at", null: false
    t.bigint "event_id", null: false
    t.string "increase_id"
    t.jsonb "increase_object"
    t.string "increase_status"
    t.string "memo"
    t.string "payment_for"
    t.bigint "payment_recipient_id"
    t.string "recipient_email"
    t.string "recipient_name"
    t.boolean "send_email_notification", default: false
    t.datetime "updated_at", null: false
    t.bigint "user_id"
    t.index "(((increase_object -> 'deposit'::text) ->> 'transaction_id'::text))", name: "index_increase_checks_on_transaction_id"
    t.index ["column_id"], name: "index_increase_checks_on_column_id", unique: true
    t.index ["event_id"], name: "index_increase_checks_on_event_id"
    t.index ["payment_recipient_id"], name: "index_increase_checks_on_payment_recipient_id"
    t.index ["user_id"], name: "index_increase_checks_on_user_id"
  end

  create_table "invoice_payouts", force: :cascade do |t|
    t.bigint "amount"
    t.datetime "arrival_date", precision: nil
    t.boolean "automatic"
    t.datetime "created_at", precision: nil, null: false
    t.text "currency"
    t.text "description"
    t.text "failure_code"
    t.text "failure_message"
    t.text "failure_stripe_balance_transaction_id"
    t.text "method"
    t.text "source_type"
    t.text "statement_descriptor"
    t.text "status"
    t.text "stripe_balance_transaction_id"
    t.datetime "stripe_created_at", precision: nil
    t.text "stripe_destination_id"
    t.text "stripe_payout_id"
    t.text "type"
    t.datetime "updated_at", precision: nil, null: false
    t.index ["failure_stripe_balance_transaction_id"], name: "index_invoice_payouts_on_failure_stripe_balance_transaction_id", unique: true
    t.index ["stripe_balance_transaction_id"], name: "index_invoice_payouts_on_stripe_balance_transaction_id", unique: true
    t.index ["stripe_payout_id"], name: "index_invoice_payouts_on_stripe_payout_id", unique: true
  end

  create_table "invoices", force: :cascade do |t|
    t.string "aasm_state"
    t.bigint "amount_due"
    t.bigint "amount_paid"
    t.bigint "amount_remaining"
    t.datetime "archived_at", precision: nil
    t.bigint "archived_by_id"
    t.bigint "attempt_count"
    t.boolean "attempted"
    t.boolean "auto_advance"
    t.datetime "created_at", precision: nil, null: false
    t.bigint "creator_id"
    t.datetime "due_date", precision: nil
    t.bigint "ending_balance"
    t.bigint "fee_reimbursement_id"
    t.datetime "finalized_at", precision: nil
    t.text "hcb_code"
    t.text "hosted_invoice_url"
    t.text "invoice_pdf"
    t.bigint "item_amount"
    t.text "item_description"
    t.text "item_stripe_id"
    t.boolean "livemode"
    t.datetime "manually_marked_as_paid_at", precision: nil
    t.text "manually_marked_as_paid_reason"
    t.bigint "manually_marked_as_paid_user_id"
    t.text "memo"
    t.text "number"
    t.text "payment_method_ach_credit_transfer_account_number_ciphertext"
    t.text "payment_method_ach_credit_transfer_bank_name"
    t.text "payment_method_ach_credit_transfer_routing_number"
    t.text "payment_method_ach_credit_transfer_swift_code"
    t.text "payment_method_card_brand"
    t.text "payment_method_card_checks_address_line1_check"
    t.text "payment_method_card_checks_address_postal_code_check"
    t.text "payment_method_card_checks_cvc_check"
    t.text "payment_method_card_country"
    t.text "payment_method_card_exp_month"
    t.text "payment_method_card_exp_year"
    t.text "payment_method_card_funding"
    t.text "payment_method_card_last4"
    t.text "payment_method_type"
    t.datetime "payout_creation_balance_available_at", precision: nil
    t.integer "payout_creation_balance_net"
    t.integer "payout_creation_balance_stripe_fee"
    t.datetime "payout_creation_queued_at", precision: nil
    t.datetime "payout_creation_queued_for", precision: nil
    t.text "payout_creation_queued_job_id"
    t.bigint "payout_id"
    t.boolean "reimbursable", default: true
    t.text "slug"
    t.bigint "sponsor_id"
    t.bigint "starting_balance"
    t.text "statement_descriptor"
    t.text "status"
    t.text "stripe_charge_id"
    t.text "stripe_invoice_id"
    t.bigint "subtotal"
    t.bigint "tax"
    t.decimal "tax_percent"
    t.bigint "total"
    t.datetime "updated_at", precision: nil, null: false
    t.datetime "void_v2_at"
    t.bigint "voided_by_id"
    t.index ["archived_by_id"], name: "index_invoices_on_archived_by_id"
    t.index ["creator_id"], name: "index_invoices_on_creator_id"
    t.index ["fee_reimbursement_id"], name: "index_invoices_on_fee_reimbursement_id"
    t.index ["item_stripe_id"], name: "index_invoices_on_item_stripe_id", unique: true
    t.index ["manually_marked_as_paid_user_id"], name: "index_invoices_on_manually_marked_as_paid_user_id"
    t.index ["payout_creation_queued_job_id"], name: "index_invoices_on_payout_creation_queued_job_id", unique: true
    t.index ["payout_id"], name: "index_invoices_on_payout_id"
    t.index ["slug"], name: "index_invoices_on_slug", unique: true
    t.index ["sponsor_id"], name: "index_invoices_on_sponsor_id"
    t.index ["status"], name: "index_invoices_on_status"
    t.index ["stripe_invoice_id"], name: "index_invoices_on_stripe_invoice_id", unique: true
    t.index ["voided_by_id"], name: "index_invoices_on_voided_by_id"
  end

  create_table "lob_addresses", force: :cascade do |t|
    t.string "address1"
    t.string "address2"
    t.string "city"
    t.string "country"
    t.datetime "created_at", precision: nil, null: false
    t.text "description"
    t.bigint "event_id"
    t.string "lob_id"
    t.string "name"
    t.string "state"
    t.datetime "updated_at", precision: nil, null: false
    t.string "zip"
    t.index ["event_id"], name: "index_lob_addresses_on_event_id"
  end

  create_table "login_codes", force: :cascade do |t|
    t.text "code"
    t.datetime "created_at", null: false
    t.inet "ip_address"
    t.datetime "updated_at", null: false
    t.datetime "used_at"
    t.text "user_agent"
    t.bigint "user_id"
    t.index ["code"], name: "index_login_codes_on_code"
    t.index ["user_id"], name: "index_login_codes_on_user_id"
  end

  create_table "logins", force: :cascade do |t|
    t.string "aasm_state"
    t.jsonb "authentication_factors"
    t.text "browser_token_ciphertext"
    t.datetime "created_at", null: false
    t.boolean "is_reauthentication", default: false, null: false
    t.bigint "referral_link_id"
    t.bigint "referral_program_id"
    t.datetime "updated_at", null: false
    t.bigint "user_id", null: false
    t.bigint "user_session_id"
    t.index ["referral_link_id"], name: "index_logins_on_referral_link_id"
    t.index ["referral_program_id"], name: "index_logins_on_referral_program_id"
    t.index ["user_id"], name: "index_logins_on_user_id"
    t.index ["user_session_id"], name: "index_logins_on_user_session_id"
  end

  create_table "mailbox_addresses", force: :cascade do |t|
    t.string "aasm_state"
    t.string "address", null: false
    t.datetime "created_at", null: false
    t.datetime "discarded_at"
    t.datetime "updated_at", null: false
    t.bigint "user_id", null: false
    t.index ["address"], name: "index_mailbox_addresses_on_address", unique: true
    t.index ["user_id"], name: "index_mailbox_addresses_on_user_id"
  end

  create_table "metrics", force: :cascade do |t|
    t.string "aasm_state"
    t.datetime "canceled_at"
    t.datetime "completed_at"
    t.datetime "created_at", null: false
    t.datetime "failed_at"
    t.jsonb "metric"
    t.datetime "processing_at"
    t.bigint "subject_id"
    t.string "subject_type"
    t.string "type", null: false
    t.datetime "updated_at", null: false
    t.integer "year"
    t.index ["subject_type", "subject_id", "type", "year"], name: "index_metrics_on_subject_type_and_subject_id_and_type_and_year", unique: true
    t.index ["subject_type", "subject_id"], name: "index_metrics_on_subject"
  end

  create_table "oauth_access_grants", force: :cascade do |t|
    t.bigint "application_id", null: false
    t.string "code_challenge"
    t.string "code_challenge_method"
    t.datetime "created_at", null: false
    t.integer "expires_in", null: false
    t.text "redirect_uri", null: false
    t.bigint "resource_owner_id", null: false
    t.datetime "revoked_at"
    t.string "scopes", default: "", null: false
    t.string "token", null: false
    t.index ["application_id"], name: "index_oauth_access_grants_on_application_id"
    t.index ["resource_owner_id"], name: "index_oauth_access_grants_on_resource_owner_id"
    t.index ["token"], name: "index_oauth_access_grants_on_token", unique: true
  end

  create_table "oauth_applications", force: :cascade do |t|
    t.boolean "confidential", default: true, null: false
    t.datetime "created_at", null: false
    t.string "name", null: false
    t.text "redirect_uri", null: false
    t.string "scopes", default: "", null: false
    t.string "secret", null: false
    t.boolean "trusted", default: false, null: false
    t.string "uid", null: false
    t.datetime "updated_at", null: false
    t.index ["uid"], name: "index_oauth_applications_on_uid", unique: true
  end

  create_table "oauth_device_grants", force: :cascade do |t|
    t.bigint "application_id", null: false
    t.datetime "created_at", null: false
    t.string "device_code", null: false
    t.integer "expires_in", null: false
    t.datetime "last_polling_at"
    t.bigint "resource_owner_id"
    t.string "scopes", default: "", null: false
    t.string "user_code"
    t.index ["application_id"], name: "index_oauth_device_grants_on_application_id"
    t.index ["device_code"], name: "index_oauth_device_grants_on_device_code", unique: true
    t.index ["resource_owner_id"], name: "index_oauth_device_grants_on_resource_owner_id"
    t.index ["user_code"], name: "index_oauth_device_grants_on_user_code", unique: true
  end

  create_table "organizer_position_deletion_requests", force: :cascade do |t|
    t.datetime "closed_at", precision: nil
    t.bigint "closed_by_id"
    t.datetime "created_at", precision: nil, null: false
    t.bigint "organizer_position_id"
    t.text "reason"
    t.boolean "subject_emails_should_be_forwarded", default: false, null: false
    t.boolean "subject_has_active_cards", default: false, null: false
    t.boolean "subject_has_outstanding_expenses_expensify", default: false, null: false
    t.boolean "subject_has_outstanding_transactions_emburse", default: false, null: false
    t.boolean "subject_has_outstanding_transactions_stripe", default: false, null: false
    t.bigint "submitted_by_id"
    t.datetime "updated_at", precision: nil, null: false
    t.index ["closed_by_id"], name: "index_organizer_position_deletion_requests_on_closed_by_id"
    t.index ["organizer_position_id"], name: "index_organizer_deletion_requests_on_organizer_position_id"
    t.index ["submitted_by_id"], name: "index_organizer_position_deletion_requests_on_submitted_by_id"
  end

  create_table "organizer_position_invite_links", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.bigint "creator_id", null: false
    t.datetime "deactivated_at"
    t.bigint "deactivator_id"
    t.bigint "event_id", null: false
    t.integer "expires_in", default: 2592000, null: false
    t.datetime "updated_at", null: false
    t.index ["creator_id"], name: "index_organizer_position_invite_links_on_creator_id"
    t.index ["deactivator_id"], name: "index_organizer_position_invite_links_on_deactivator_id"
    t.index ["event_id"], name: "index_organizer_position_invite_links_on_event_id"
  end

  create_table "organizer_position_invite_requests", force: :cascade do |t|
    t.string "aasm_state", null: false
    t.datetime "created_at", null: false
    t.bigint "organizer_position_invite_id"
    t.bigint "organizer_position_invite_link_id", null: false
    t.bigint "requester_id", null: false
    t.datetime "updated_at", null: false
    t.index ["organizer_position_invite_id"], name: "idx_on_organizer_position_invite_id_0bf62e304a"
    t.index ["organizer_position_invite_link_id"], name: "idx_on_organizer_position_invite_link_id_241807b5ee"
    t.index ["requester_id"], name: "index_organizer_position_invite_requests_on_requester_id"
  end

  create_table "organizer_position_invites", force: :cascade do |t|
    t.datetime "accepted_at", precision: nil
    t.datetime "cancelled_at", precision: nil
    t.datetime "created_at", precision: nil, null: false
    t.bigint "event_id", null: false
    t.boolean "initial", default: false
    t.integer "initial_control_allowance_amount_cents"
    t.boolean "is_signee", default: false
    t.bigint "organizer_position_id"
    t.datetime "rejected_at", precision: nil
    t.integer "role", default: 100, null: false
    t.bigint "sender_id"
    t.string "slug"
    t.datetime "updated_at", precision: nil, null: false
    t.bigint "user_id", null: false
    t.index ["event_id"], name: "index_organizer_position_invites_on_event_id"
    t.index ["organizer_position_id"], name: "index_organizer_position_invites_on_organizer_position_id"
    t.index ["sender_id"], name: "index_organizer_position_invites_on_sender_id"
    t.index ["slug"], name: "index_organizer_position_invites_on_slug", unique: true
    t.index ["user_id"], name: "index_organizer_position_invites_on_user_id"
  end

  create_table "organizer_position_spending_control_allowances", force: :cascade do |t|
    t.integer "amount_cents", null: false
    t.bigint "authorized_by_id", null: false
    t.datetime "created_at", null: false
    t.text "memo"
    t.bigint "organizer_position_spending_control_id", null: false
    t.datetime "updated_at", null: false
    t.index ["authorized_by_id"], name: "idx_org_pos_spend_ctrl_allows_on_authed_by_id"
    t.index ["organizer_position_spending_control_id"], name: "idx_org_pos_spend_ctrl_allows_on_org_pos_spend_ctrl_id"
  end

  create_table "organizer_position_spending_controls", force: :cascade do |t|
    t.boolean "active", default: true
    t.datetime "created_at", null: false
    t.datetime "ended_at"
    t.bigint "organizer_position_id", null: false
    t.datetime "updated_at", null: false
    t.index ["organizer_position_id"], name: "idx_org_pos_spend_ctrls_on_org_pos_id"
  end

  create_table "organizer_positions", force: :cascade do |t|
    t.datetime "created_at", precision: nil, null: false
    t.datetime "deleted_at", precision: nil
    t.bigint "event_id"
    t.boolean "first_time", default: true
    t.bigint "fiscal_sponsorship_contract_id"
    t.boolean "is_signee", default: false
    t.integer "role", default: 100, null: false
    t.integer "sort_index"
    t.datetime "updated_at", precision: nil, null: false
    t.bigint "user_id"
    t.index ["event_id"], name: "index_organizer_positions_on_event_id"
    t.index ["fiscal_sponsorship_contract_id"], name: "index_organizer_positions_on_fiscal_sponsorship_contract_id"
    t.index ["user_id"], name: "index_organizer_positions_on_user_id"
  end

  create_table "outgoing_twilio_messages", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.bigint "hcb_code_id"
    t.bigint "twilio_message_id"
    t.datetime "updated_at", null: false
    t.index ["hcb_code_id"], name: "index_outgoing_twilio_messages_on_hcb_code_id"
    t.index ["twilio_message_id"], name: "index_outgoing_twilio_messages_on_twilio_message_id"
  end

  create_table "payment_recipients", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.text "email"
    t.bigint "event_id", null: false
    t.text "information_ciphertext"
    t.string "name"
    t.string "payment_model"
    t.datetime "updated_at", null: false
    t.index ["event_id"], name: "index_payment_recipients_on_event_id"
    t.index ["name"], name: "index_payment_recipients_on_name"
  end

  create_table "paypal_transfers", force: :cascade do |t|
    t.string "aasm_state", null: false
    t.integer "amount_cents", null: false
    t.datetime "approved_at"
    t.datetime "created_at", null: false
    t.bigint "event_id", null: false
    t.string "memo", null: false
    t.string "payment_for", null: false
    t.string "recipient_email", null: false
    t.string "recipient_name", null: false
    t.datetime "updated_at", null: false
    t.bigint "user_id", null: false
    t.index ["event_id"], name: "index_paypal_transfers_on_event_id"
    t.index ["user_id"], name: "index_paypal_transfers_on_user_id"
  end

  create_table "raffles", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.string "program", null: false
    t.datetime "updated_at", null: false
    t.bigint "user_id", null: false
    t.index ["program", "user_id"], name: "index_raffles_on_program_and_user_id", unique: true
  end

  create_table "raw_column_transactions", force: :cascade do |t|
    t.integer "amount_cents"
    t.string "column_report_id"
    t.jsonb "column_transaction"
    t.jsonb "column_transfer"
    t.datetime "created_at", null: false
    t.date "date_posted"
    t.text "description"
    t.integer "transaction_index"
    t.datetime "updated_at", null: false
  end

  create_table "raw_csv_transactions", force: :cascade do |t|
    t.integer "amount_cents"
    t.datetime "created_at", null: false
    t.text "csv_transaction_id"
    t.date "date_posted"
    t.text "memo"
    t.jsonb "raw_data"
    t.string "unique_bank_identifier", null: false
    t.datetime "updated_at", null: false
    t.index ["csv_transaction_id"], name: "index_raw_csv_transactions_on_csv_transaction_id", unique: true
  end

  create_table "raw_emburse_transactions", force: :cascade do |t|
    t.integer "amount_cents"
    t.datetime "created_at", null: false
    t.date "date_posted"
    t.jsonb "emburse_transaction"
    t.text "emburse_transaction_id"
    t.string "state"
    t.string "unique_bank_identifier", null: false
    t.datetime "updated_at", null: false
  end

  create_table "raw_increase_transactions", force: :cascade do |t|
    t.integer "amount_cents"
    t.datetime "created_at", null: false
    t.date "date_posted"
    t.text "description"
    t.text "increase_account_id"
    t.text "increase_route_id"
    t.text "increase_route_type"
    t.jsonb "increase_transaction"
    t.text "increase_transaction_id"
    t.datetime "updated_at", null: false
    t.index ["increase_transaction_id"], name: "index_raw_increase_transactions_on_increase_transaction_id", unique: true
  end

  create_table "raw_intrafi_transactions", force: :cascade do |t|
    t.integer "amount_cents", null: false
    t.datetime "created_at", null: false
    t.date "date_posted", null: false
    t.string "memo", null: false
    t.datetime "updated_at", null: false
  end

  create_table "raw_pending_bank_fee_transactions", force: :cascade do |t|
    t.integer "amount_cents"
    t.string "bank_fee_transaction_id"
    t.datetime "created_at", null: false
    t.date "date_posted"
    t.string "state"
    t.datetime "updated_at", null: false
  end

  create_table "raw_pending_column_transactions", force: :cascade do |t|
    t.integer "amount_cents", null: false
    t.integer "column_event_type", null: false
    t.string "column_id", null: false
    t.jsonb "column_transaction", null: false
    t.datetime "created_at", null: false
    t.date "date_posted", null: false
    t.text "description", null: false
    t.datetime "updated_at", null: false
    t.index ["column_id"], name: "index_raw_pending_column_transactions_on_column_id", unique: true
  end

  create_table "raw_pending_donation_transactions", force: :cascade do |t|
    t.integer "amount_cents"
    t.datetime "created_at", null: false
    t.date "date_posted"
    t.string "donation_transaction_id"
    t.string "state"
    t.datetime "updated_at", null: false
  end

  create_table "raw_pending_incoming_disbursement_transactions", force: :cascade do |t|
    t.integer "amount_cents"
    t.datetime "created_at", null: false
    t.date "date_posted"
    t.bigint "disbursement_id"
    t.string "state"
    t.datetime "updated_at", null: false
    t.index ["disbursement_id"], name: "index_rpidts_on_disbursement_id"
  end

  create_table "raw_pending_invoice_transactions", force: :cascade do |t|
    t.integer "amount_cents"
    t.datetime "created_at", null: false
    t.date "date_posted"
    t.string "invoice_transaction_id"
    t.string "state"
    t.datetime "updated_at", null: false
  end

  create_table "raw_pending_outgoing_ach_transactions", force: :cascade do |t|
    t.text "ach_transaction_id"
    t.integer "amount_cents"
    t.datetime "created_at", null: false
    t.date "date_posted"
    t.string "state"
    t.datetime "updated_at", null: false
  end

  create_table "raw_pending_outgoing_check_transactions", force: :cascade do |t|
    t.integer "amount_cents"
    t.string "check_transaction_id"
    t.datetime "created_at", null: false
    t.date "date_posted"
    t.string "state"
    t.datetime "updated_at", null: false
  end

  create_table "raw_pending_outgoing_disbursement_transactions", force: :cascade do |t|
    t.integer "amount_cents"
    t.datetime "created_at", null: false
    t.date "date_posted"
    t.bigint "disbursement_id"
    t.string "state"
    t.datetime "updated_at", null: false
    t.index ["disbursement_id"], name: "index_rpodts_on_disbursement_id"
  end

  create_table "raw_pending_stripe_transactions", force: :cascade do |t|
    t.integer "amount_cents"
    t.datetime "created_at", null: false
    t.date "date_posted"
    t.jsonb "stripe_transaction"
    t.text "stripe_transaction_id"
    t.datetime "updated_at", null: false
    t.index "((((stripe_transaction -> 'card'::text) -> 'cardholder'::text) ->> 'id'::text))", name: "index_raw_pending_stripe_transactions_on_cardholder_id"
    t.index "(((stripe_transaction -> 'card'::text) ->> 'id'::text))", name: "index_raw_pending_stripe_transactions_on_card_id_text", using: :hash
    t.index "((stripe_transaction ->> 'status'::text))", name: "index_raw_pending_stripe_transactions_on_status_text", using: :hash
    t.index ["stripe_transaction_id"], name: "index_raw_pending_stripe_transactions_on_stripe_transaction_id", unique: true
  end

  create_table "raw_plaid_transactions", force: :cascade do |t|
    t.integer "amount_cents"
    t.datetime "created_at", null: false
    t.date "date_posted"
    t.boolean "pending", default: false
    t.text "plaid_account_id"
    t.text "plaid_item_id"
    t.jsonb "plaid_transaction"
    t.text "plaid_transaction_id"
    t.string "unique_bank_identifier", null: false
    t.datetime "updated_at", null: false
  end

  create_table "raw_stripe_transactions", force: :cascade do |t|
    t.integer "amount_cents"
    t.datetime "created_at", null: false
    t.date "date_posted"
    t.text "stripe_authorization_id"
    t.jsonb "stripe_transaction"
    t.text "stripe_transaction_id"
    t.string "unique_bank_identifier", null: false
    t.datetime "updated_at", null: false
    t.index "(((stripe_transaction -> 'card'::text) ->> 'id'::text))", name: "index_raw_stripe_transactions_on_card_id_text", using: :hash
  end

  create_table "receipts", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.boolean "data_extracted", default: false, null: false
    t.text "extracted_card_last4_ciphertext"
    t.string "extracted_currency"
    t.datetime "extracted_date"
    t.string "extracted_merchant_name"
    t.string "extracted_merchant_url"
    t.string "extracted_merchant_zip_code"
    t.integer "extracted_subtotal_amount_cents"
    t.integer "extracted_total_amount_cents"
    t.bigint "receiptable_id"
    t.string "receiptable_type"
    t.string "suggested_memo"
    t.string "textual_content_bidx"
    t.text "textual_content_ciphertext"
    t.integer "textual_content_source", default: 0
    t.datetime "updated_at", null: false
    t.integer "upload_method"
    t.bigint "user_id"
    t.index ["receiptable_type", "receiptable_id"], name: "index_receipts_on_receiptable_type_and_receiptable_id"
    t.index ["textual_content_bidx"], name: "index_receipts_on_textual_content_bidx"
    t.index ["user_id"], name: "index_receipts_on_user_id"
  end

  create_table "recurring_donations", force: :cascade do |t|
    t.integer "amount"
    t.boolean "anonymous", default: false, null: false
    t.datetime "canceled_at"
    t.datetime "created_at", null: false
    t.text "email"
    t.bigint "event_id", null: false
    t.boolean "fee_covered", default: false, null: false
    t.text "last4_ciphertext"
    t.text "message"
    t.boolean "migrated_from_legacy_stripe_account", default: false
    t.text "name"
    t.text "stripe_client_secret"
    t.datetime "stripe_current_period_end"
    t.text "stripe_customer_id"
    t.text "stripe_payment_intent_id"
    t.text "stripe_status"
    t.text "stripe_subscription_id"
    t.boolean "tax_deductible", default: true, null: false
    t.datetime "updated_at", null: false
    t.text "url_hash"
    t.index ["event_id"], name: "index_recurring_donations_on_event_id"
    t.index ["stripe_subscription_id"], name: "index_recurring_donations_on_stripe_subscription_id", unique: true
    t.index ["url_hash"], name: "index_recurring_donations_on_url_hash", unique: true
  end

  create_table "referral_attributions", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.bigint "referral_link_id", null: false
    t.bigint "referral_program_id", null: false
    t.datetime "updated_at", null: false
    t.bigint "user_id", null: false
    t.index ["referral_link_id"], name: "index_referral_attributions_on_referral_link_id"
    t.index ["referral_program_id"], name: "index_referral_attributions_on_referral_program_id"
    t.index ["user_id", "referral_program_id"], name: "index_referral_attributions_on_user_id_and_referral_program_id", unique: true
    t.index ["user_id"], name: "index_referral_attributions_on_user_id"
  end

  create_table "referral_links", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.bigint "creator_id", null: false
    t.string "name", null: false
    t.bigint "program_id", null: false
    t.string "slug"
    t.datetime "updated_at", null: false
    t.index ["creator_id"], name: "index_referral_links_on_creator_id"
    t.index ["program_id"], name: "index_referral_links_on_program_id"
    t.index ["slug"], name: "index_referral_links_on_slug", unique: true
  end

  create_table "referral_programs", force: :cascade do |t|
    t.string "background_image_url"
    t.datetime "created_at", null: false
    t.bigint "creator_id", null: false
    t.text "login_body_text"
    t.string "login_header_text"
    t.string "login_text_color"
    t.string "name", null: false
    t.string "redirect_to"
    t.datetime "updated_at", null: false
    t.index ["creator_id"], name: "index_referral_programs_on_creator_id"
  end

  create_table "reimbursement_expense_payouts", force: :cascade do |t|
    t.string "aasm_state"
    t.integer "amount_cents", null: false
    t.datetime "created_at", null: false
    t.bigint "event_id", null: false
    t.string "hcb_code"
    t.bigint "reimbursement_expenses_id", null: false
    t.bigint "reimbursement_payout_holdings_id"
    t.datetime "updated_at", null: false
    t.index ["event_id"], name: "index_reimbursement_expense_payouts_on_event_id"
    t.index ["reimbursement_expenses_id"], name: "index_expense_payouts_on_expenses_id"
    t.index ["reimbursement_payout_holdings_id"], name: "index_expense_payouts_on_expense_payout_holdings_id"
  end

  create_table "reimbursement_expenses", force: :cascade do |t|
    t.string "aasm_state"
    t.integer "amount_cents", default: 0, null: false
    t.datetime "approved_at"
    t.bigint "approved_by_id"
    t.integer "category"
    t.datetime "created_at", null: false
    t.datetime "deleted_at", precision: nil
    t.text "description"
    t.integer "expense_number", null: false
    t.text "memo"
    t.bigint "reimbursement_report_id", null: false
    t.string "type"
    t.datetime "updated_at", null: false
    t.decimal "value", default: "0.0", null: false
    t.index ["approved_by_id"], name: "index_reimbursement_expenses_on_approved_by_id"
    t.index ["reimbursement_report_id"], name: "index_reimbursement_expenses_on_reimbursement_report_id"
  end

  create_table "reimbursement_payout_holdings", force: :cascade do |t|
    t.string "aasm_state"
    t.bigint "ach_transfer_id"
    t.integer "amount_cents", null: false
    t.datetime "created_at", null: false
    t.string "hcb_code"
    t.bigint "increase_check_id"
    t.bigint "paypal_transfer_id"
    t.bigint "reimbursement_reports_id", null: false
    t.datetime "updated_at", null: false
    t.bigint "wire_id"
    t.bigint "wise_transfer_id"
    t.index ["ach_transfer_id"], name: "index_reimbursement_payout_holdings_on_ach_transfer_id"
    t.index ["increase_check_id"], name: "index_reimbursement_payout_holdings_on_increase_check_id"
    t.index ["paypal_transfer_id"], name: "index_reimbursement_payout_holdings_on_paypal_transfer_id"
    t.index ["reimbursement_reports_id"], name: "index_reimbursement_payout_holdings_on_reimbursement_reports_id"
    t.index ["wire_id"], name: "index_reimbursement_payout_holdings_on_wire_id"
    t.index ["wise_transfer_id"], name: "index_reimbursement_payout_holdings_on_wise_transfer_id"
  end

  create_table "reimbursement_reports", force: :cascade do |t|
    t.string "aasm_state"
    t.bigint "card_grant_id"
    t.float "conversion_rate", default: 1.0, null: false
    t.datetime "created_at", null: false
    t.string "currency", default: "USD", null: false
    t.datetime "deleted_at", precision: nil
    t.bigint "event_id"
    t.integer "expense_number", default: 0, null: false
    t.text "invite_message"
    t.bigint "invited_by_id"
    t.integer "maximum_amount_cents"
    t.text "name"
    t.datetime "reimbursed_at"
    t.datetime "reimbursement_approved_at"
    t.datetime "reimbursement_requested_at"
    t.datetime "rejected_at"
    t.bigint "reviewer_id"
    t.datetime "submitted_at"
    t.datetime "updated_at", null: false
    t.bigint "user_id", null: false
    t.index ["card_grant_id"], name: "index_reimbursement_reports_on_card_grant_id"
    t.index ["event_id"], name: "index_reimbursement_reports_on_event_id"
    t.index ["invited_by_id"], name: "index_reimbursement_reports_on_invited_by_id"
    t.index ["reviewer_id"], name: "index_reimbursement_reports_on_reviewer_id"
    t.index ["user_id"], name: "index_reimbursement_reports_on_user_id"
  end

  create_table "sponsors", force: :cascade do |t|
    t.text "address_city"
    t.text "address_country", default: "US"
    t.text "address_line1"
    t.text "address_line2"
    t.text "address_postal_code"
    t.text "address_state"
    t.text "contact_email"
    t.datetime "created_at", precision: nil, null: false
    t.bigint "event_id"
    t.text "name"
    t.text "slug"
    t.text "stripe_customer_id"
    t.datetime "updated_at", precision: nil, null: false
    t.index ["event_id"], name: "index_sponsors_on_event_id"
    t.index ["slug"], name: "index_sponsors_on_slug", unique: true
  end

  create_table "stripe_authorizations", force: :cascade do |t|
    t.integer "amount"
    t.boolean "approved", default: false, null: false
    t.integer "authorization_method"
    t.datetime "created_at", null: false
    t.string "display_name"
    t.datetime "marked_no_or_lost_receipt_at", precision: nil
    t.string "name"
    t.bigint "stripe_card_id", null: false
    t.text "stripe_id"
    t.integer "stripe_status"
    t.datetime "updated_at", null: false
    t.index ["stripe_card_id"], name: "index_stripe_authorizations_on_stripe_card_id"
  end

  create_table "stripe_card_personalization_designs", force: :cascade do |t|
    t.boolean "common", default: false, null: false
    t.datetime "created_at", null: false
    t.bigint "event_id"
    t.boolean "stale", default: false, null: false
    t.string "stripe_card_logo"
    t.jsonb "stripe_carrier_text"
    t.string "stripe_id"
    t.string "stripe_name"
    t.string "stripe_physical_bundle_id"
    t.string "stripe_status"
    t.datetime "updated_at", null: false
    t.index ["event_id"], name: "index_stripe_card_personalization_designs_on_event_id"
  end

  create_table "stripe_cardholders", force: :cascade do |t|
    t.integer "cardholder_type", default: 0, null: false
    t.datetime "created_at", null: false
    t.text "stripe_billing_address_city"
    t.text "stripe_billing_address_country"
    t.text "stripe_billing_address_line1"
    t.text "stripe_billing_address_line2"
    t.text "stripe_billing_address_postal_code"
    t.text "stripe_billing_address_state"
    t.text "stripe_email"
    t.text "stripe_id"
    t.text "stripe_name"
    t.text "stripe_phone_number"
    t.datetime "updated_at", null: false
    t.bigint "user_id", null: false
    t.index ["stripe_id"], name: "index_stripe_cardholders_on_stripe_id"
    t.index ["user_id"], name: "index_stripe_cardholders_on_user_id"
  end

  create_table "stripe_cards", force: :cascade do |t|
    t.datetime "canceled_at"
    t.integer "card_type", default: 0, null: false
    t.boolean "cash_withdrawal_enabled", default: false
    t.datetime "created_at", null: false
    t.bigint "event_id", null: false
    t.boolean "initially_activated", default: false, null: false
    t.boolean "is_platinum_april_fools_2023"
    t.text "last4"
    t.bigint "last_frozen_by_id"
    t.boolean "lost_in_shipping", default: false
    t.string "name"
    t.datetime "purchased_at", precision: nil
    t.bigint "replacement_for_id"
    t.integer "spending_limit_amount"
    t.integer "spending_limit_interval"
    t.text "stripe_brand"
    t.integer "stripe_card_personalization_design_id"
    t.bigint "stripe_cardholder_id", null: false
    t.integer "stripe_exp_month"
    t.integer "stripe_exp_year"
    t.text "stripe_id"
    t.text "stripe_shipping_address_city"
    t.text "stripe_shipping_address_country"
    t.text "stripe_shipping_address_line1"
    t.text "stripe_shipping_address_line2"
    t.text "stripe_shipping_address_postal_code"
    t.text "stripe_shipping_address_state"
    t.text "stripe_shipping_name"
    t.text "stripe_status"
    t.bigint "subledger_id"
    t.datetime "updated_at", null: false
    t.index ["event_id"], name: "index_stripe_cards_on_event_id"
    t.index ["last_frozen_by_id"], name: "index_stripe_cards_on_last_frozen_by_id"
    t.index ["replacement_for_id"], name: "index_stripe_cards_on_replacement_for_id"
    t.index ["stripe_cardholder_id"], name: "index_stripe_cards_on_stripe_cardholder_id"
    t.index ["stripe_id"], name: "index_stripe_cards_on_stripe_id", unique: true
    t.index ["subledger_id"], name: "index_stripe_cards_on_subledger_id"
  end

  create_table "stripe_service_fees", force: :cascade do |t|
    t.integer "amount_cents", null: false
    t.datetime "created_at", null: false
    t.string "stripe_balance_transaction_id", null: false
    t.string "stripe_description", null: false
    t.bigint "stripe_topup_id"
    t.datetime "updated_at", null: false
    t.index ["stripe_balance_transaction_id"], name: "index_stripe_service_fees_on_stripe_balance_transaction_id", unique: true
    t.index ["stripe_topup_id"], name: "index_stripe_service_fees_on_stripe_topup_id"
  end

  create_table "stripe_topups", force: :cascade do |t|
    t.integer "amount_cents", null: false
    t.datetime "created_at", null: false
    t.string "description", null: false
    t.jsonb "metadata"
    t.string "statement_descriptor", null: false
    t.string "stripe_id"
    t.datetime "updated_at", null: false
    t.index ["stripe_id"], name: "index_stripe_topups_on_stripe_id", unique: true
  end

  create_table "subledgers", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.bigint "event_id", null: false
    t.datetime "updated_at", null: false
    t.index ["event_id"], name: "index_subledgers_on_event_id"
  end

  create_table "suggested_pairings", force: :cascade do |t|
    t.string "aasm_state"
    t.datetime "accepted_at"
    t.datetime "created_at", null: false
    t.float "distance"
    t.bigint "hcb_code_id", null: false
    t.datetime "ignored_at"
    t.bigint "receipt_id", null: false
    t.datetime "updated_at", null: false
    t.index ["hcb_code_id"], name: "index_suggested_pairings_on_hcb_code_id"
    t.index ["receipt_id", "hcb_code_id"], name: "index_suggested_pairings_on_receipt_id_and_hcb_code_id", unique: true
    t.index ["receipt_id"], name: "index_suggested_pairings_on_receipt_id"
  end

  create_table "tags", force: :cascade do |t|
    t.text "color"
    t.datetime "created_at", null: false
    t.string "emoji"
    t.bigint "event_id", null: false
    t.text "label"
    t.datetime "updated_at", null: false
    t.index ["event_id"], name: "index_tags_on_event_id"
    t.check_constraint "emoji IS NOT NULL", name: "tags_emoji_null"
  end

  create_table "tasks", force: :cascade do |t|
    t.bigint "assignee_id", null: false
    t.string "assignee_type", null: false
    t.boolean "complete", default: false
    t.datetime "completed_at"
    t.datetime "created_at", null: false
    t.bigint "taskable_id", null: false
    t.string "taskable_type", null: false
    t.string "type", null: false
    t.datetime "updated_at", null: false
    t.index ["assignee_type", "assignee_id"], name: "index_tasks_on_assignee"
    t.index ["taskable_type", "taskable_id"], name: "index_tasks_on_taskable"
  end

  create_table "tours", force: :cascade do |t|
    t.boolean "active", default: true
    t.datetime "created_at", null: false
    t.string "name"
    t.integer "step", default: 0
    t.bigint "tourable_id", null: false
    t.string "tourable_type", null: false
    t.datetime "updated_at", null: false
    t.index ["tourable_type", "tourable_id"], name: "index_tours_on_tourable"
  end

  create_table "transaction_categories", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.citext "slug", null: false
    t.datetime "updated_at", null: false
    t.index ["slug"], name: "index_transaction_categories_on_slug", unique: true
  end

  create_table "transaction_category_mappings", force: :cascade do |t|
    t.text "assignment_strategy", null: false
    t.bigint "categorizable_id", null: false
    t.text "categorizable_type", null: false
    t.datetime "created_at", null: false
    t.bigint "transaction_category_id", null: false
    t.datetime "updated_at", null: false
    t.index ["categorizable_type", "categorizable_id"], name: "idx_on_categorizable_type_categorizable_id_f3e1245d19", unique: true
    t.index ["transaction_category_id"], name: "index_transaction_category_mappings_on_transaction_category_id"
  end

  create_table "transaction_csvs", force: :cascade do |t|
    t.string "aasm_state"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
  end

  create_table "transactions", force: :cascade do |t|
    t.bigint "ach_transfer_id"
    t.bigint "amount"
    t.bigint "bank_account_id"
    t.bigint "check_id"
    t.datetime "created_at", precision: nil, null: false
    t.date "date"
    t.datetime "deleted_at", precision: nil
    t.bigint "disbursement_id"
    t.text "display_name"
    t.bigint "donation_payout_id"
    t.bigint "emburse_transfer_id"
    t.bigint "fee_reimbursement_id"
    t.bigint "fee_relationship_id"
    t.bigint "invoice_payout_id"
    t.boolean "is_event_related"
    t.text "location_address"
    t.text "location_city"
    t.decimal "location_lat"
    t.decimal "location_lng"
    t.text "location_state"
    t.text "location_zip"
    t.text "name"
    t.text "payment_meta_by_order_of"
    t.text "payment_meta_payee"
    t.text "payment_meta_payer"
    t.text "payment_meta_payment_method"
    t.text "payment_meta_payment_processor"
    t.text "payment_meta_ppd_id"
    t.text "payment_meta_reason"
    t.text "payment_meta_reference_number"
    t.boolean "pending"
    t.text "pending_transaction_id"
    t.text "plaid_category_id"
    t.text "plaid_id"
    t.text "slug"
    t.text "transaction_type"
    t.datetime "updated_at", precision: nil, null: false
    t.index ["ach_transfer_id"], name: "index_transactions_on_ach_transfer_id"
    t.index ["bank_account_id"], name: "index_transactions_on_bank_account_id"
    t.index ["check_id"], name: "index_transactions_on_check_id"
    t.index ["deleted_at"], name: "index_transactions_on_deleted_at"
    t.index ["disbursement_id"], name: "index_transactions_on_disbursement_id"
    t.index ["donation_payout_id"], name: "index_transactions_on_donation_payout_id"
    t.index ["emburse_transfer_id"], name: "index_transactions_on_emburse_transfer_id"
    t.index ["fee_reimbursement_id"], name: "index_transactions_on_fee_reimbursement_id"
    t.index ["fee_relationship_id"], name: "index_transactions_on_fee_relationship_id"
    t.index ["invoice_payout_id"], name: "index_transactions_on_invoice_payout_id"
    t.index ["plaid_id"], name: "index_transactions_on_plaid_id", unique: true
    t.index ["slug"], name: "index_transactions_on_slug", unique: true
  end

  create_table "twilio_messages", force: :cascade do |t|
    t.text "body"
    t.datetime "created_at", null: false
    t.text "from"
    t.jsonb "raw_data"
    t.text "to"
    t.text "twilio_account_sid"
    t.text "twilio_sid"
    t.datetime "updated_at", null: false
  end

  create_table "user_backup_codes", force: :cascade do |t|
    t.string "aasm_state", default: "previewed", null: false
    t.text "code_digest", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.bigint "user_id", null: false
    t.index ["user_id"], name: "index_user_backup_codes_on_user_id"
  end

  create_table "user_email_updates", force: :cascade do |t|
    t.string "aasm_state", null: false
    t.string "authorization_token_bidx"
    t.text "authorization_token_ciphertext"
    t.boolean "authorized", default: false, null: false
    t.datetime "created_at", null: false
    t.string "original", null: false
    t.string "replacement", null: false
    t.datetime "updated_at", null: false
    t.bigint "updated_by_id"
    t.bigint "user_id", null: false
    t.string "verification_token_bidx"
    t.text "verification_token_ciphertext"
    t.boolean "verified", default: false, null: false
    t.index ["authorization_token_bidx"], name: "index_user_email_updates_on_authorization_token_bidx"
    t.index ["updated_by_id"], name: "index_user_email_updates_on_updated_by_id"
    t.index ["user_id"], name: "index_user_email_updates_on_user_id"
    t.index ["verification_token_bidx"], name: "index_user_email_updates_on_verification_token_bidx"
  end

  create_table "user_payout_method_ach_transfers", force: :cascade do |t|
    t.text "account_number_ciphertext", null: false
    t.datetime "created_at", null: false
    t.text "routing_number_ciphertext", null: false
    t.datetime "updated_at", null: false
  end

  create_table "user_payout_method_checks", force: :cascade do |t|
    t.text "address_city", null: false
    t.text "address_country", null: false
    t.text "address_line1", null: false
    t.text "address_line2"
    t.text "address_postal_code", null: false
    t.text "address_state", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
  end

  create_table "user_payout_method_paypal_transfers", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.text "recipient_email", null: false
    t.datetime "updated_at", null: false
  end

  create_table "user_payout_method_wires", force: :cascade do |t|
    t.string "account_number_bidx", null: false
    t.string "account_number_ciphertext", null: false
    t.string "address_city"
    t.string "address_line1"
    t.string "address_line2"
    t.string "address_postal_code"
    t.string "address_state"
    t.string "bic_code_bidx", null: false
    t.string "bic_code_ciphertext", null: false
    t.datetime "created_at", null: false
    t.integer "recipient_country"
    t.jsonb "recipient_information"
    t.datetime "updated_at", null: false
  end

  create_table "user_payout_method_wise_transfers", force: :cascade do |t|
    t.string "address_city"
    t.string "address_line1"
    t.string "address_line2"
    t.string "address_postal_code"
    t.string "address_state"
    t.string "bank_name"
    t.datetime "created_at", null: false
    t.string "currency"
    t.integer "recipient_country"
    t.text "recipient_information_ciphertext"
    t.datetime "updated_at", null: false
    t.text "wise_recipient_id"
  end

  create_table "user_seen_at_histories", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.datetime "period_end_at", null: false
    t.datetime "period_start_at", null: false
    t.boolean "teenager"
    t.datetime "updated_at", null: false
    t.bigint "user_id"
    t.index ["user_id"], name: "index_user_seen_at_histories_on_user_id"
  end

  create_table "user_sessions", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.string "device_info"
    t.datetime "expiration_at", precision: nil, null: false
    t.string "fingerprint"
    t.bigint "impersonated_by_id"
    t.string "ip"
    t.datetime "last_seen_at"
    t.decimal "latitude"
    t.decimal "longitude"
    t.string "os_info"
    t.string "session_token_bidx"
    t.text "session_token_ciphertext"
    t.datetime "signed_out_at"
    t.string "timezone"
    t.datetime "updated_at", null: false
    t.bigint "user_id", null: false
    t.bigint "webauthn_credential_id"
    t.index ["impersonated_by_id"], name: "index_user_sessions_on_impersonated_by_id"
    t.index ["session_token_bidx"], name: "index_user_sessions_on_session_token_bidx"
    t.index ["user_id"], name: "index_user_sessions_on_user_id"
    t.index ["webauthn_credential_id"], name: "index_user_sessions_on_webauthn_credential_id"
  end

  create_table "user_totps", force: :cascade do |t|
    t.string "aasm_state"
    t.datetime "created_at", null: false
    t.datetime "deleted_at"
    t.datetime "last_used_at"
    t.text "secret_ciphertext", null: false
    t.datetime "updated_at", null: false
    t.bigint "user_id", null: false
    t.index ["user_id"], name: "index_user_totps_on_user_id"
  end

  create_table "users", force: :cascade do |t|
    t.integer "access_level", default: 0, null: false
    t.text "birthday_ciphertext"
    t.boolean "cards_locked", default: false, null: false
    t.integer "charge_notifications", default: 0, null: false
    t.integer "comment_notifications", default: 0, null: false
    t.datetime "created_at", precision: nil, null: false
    t.integer "creation_method"
    t.string "discord_id"
    t.text "email", null: false
    t.string "full_name"
    t.boolean "joined_as_teenager"
    t.datetime "locked_at", precision: nil
    t.bigint "payout_method_id"
    t.string "payout_method_type"
    t.text "phone_number"
    t.boolean "phone_number_verified", default: false
    t.string "preferred_name"
    t.boolean "pretend_is_not_admin", default: false, null: false
    t.integer "receipt_report_option", default: 0, null: false
    t.boolean "running_balance_enabled", default: false, null: false
    t.boolean "seasonal_themes_enabled", default: true, null: false
    t.integer "session_validity_preference", default: 259200, null: false
    t.boolean "sessions_reported", default: false, null: false
    t.string "slug"
    t.boolean "teenager"
    t.datetime "updated_at", precision: nil, null: false
    t.boolean "use_sms_auth", default: false
    t.boolean "use_two_factor_authentication", default: false
    t.string "webauthn_id"
    t.index ["discord_id"], name: "index_users_on_discord_id", unique: true
    t.index ["email"], name: "index_users_on_email", unique: true
    t.index ["slug"], name: "index_users_on_slug", unique: true
  end

  create_table "versions", force: :cascade do |t|
    t.datetime "created_at", precision: nil
    t.string "event", null: false
    t.bigint "item_id", null: false
    t.string "item_type", null: false
    t.jsonb "object"
    t.jsonb "object_changes"
    t.string "whodunnit"
    t.index ["item_type", "item_id"], name: "index_versions_on_item_type_and_item_id"
  end

  create_table "w9s", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.bigint "entity_id", null: false
    t.string "entity_type", null: false
    t.datetime "signed_at", null: false
    t.datetime "updated_at", null: false
    t.bigint "uploaded_by_id"
    t.string "url", null: false
    t.index ["uploaded_by_id"], name: "index_w9s_on_uploaded_by_id"
  end

  create_table "webauthn_credentials", force: :cascade do |t|
    t.integer "authenticator_type"
    t.datetime "created_at", null: false
    t.string "name"
    t.string "public_key"
    t.integer "sign_count"
    t.datetime "updated_at", null: false
    t.bigint "user_id", null: false
    t.string "webauthn_id"
    t.index ["user_id"], name: "index_webauthn_credentials_on_user_id"
  end

  create_table "wires", force: :cascade do |t|
    t.string "aasm_state", null: false
    t.string "account_number_bidx", null: false
    t.string "account_number_ciphertext", null: false
    t.string "address_city"
    t.string "address_line1"
    t.string "address_line2"
    t.string "address_postal_code"
    t.string "address_state"
    t.integer "amount_cents", null: false
    t.datetime "approved_at"
    t.string "bic_code_bidx", null: false
    t.string "bic_code_ciphertext", null: false
    t.text "column_id"
    t.datetime "created_at", null: false
    t.string "currency", default: "USD", null: false
    t.bigint "event_id", null: false
    t.string "memo", null: false
    t.string "payment_for", null: false
    t.bigint "payment_recipient_id"
    t.integer "recipient_country"
    t.string "recipient_email", null: false
    t.jsonb "recipient_information"
    t.string "recipient_name", null: false
    t.text "return_reason"
    t.boolean "send_email_notification", default: false
    t.datetime "updated_at", null: false
    t.bigint "user_id", null: false
    t.index ["column_id"], name: "index_wires_on_column_id", unique: true
    t.index ["event_id"], name: "index_wires_on_event_id"
    t.index ["payment_recipient_id"], name: "index_wires_on_payment_recipient_id"
    t.index ["user_id"], name: "index_wires_on_user_id"
  end

  create_table "wise_transfers", force: :cascade do |t|
    t.string "aasm_state"
    t.string "address_city"
    t.string "address_line1"
    t.string "address_line2"
    t.string "address_postal_code"
    t.string "address_state"
    t.integer "amount_cents", null: false
    t.datetime "approved_at"
    t.string "bank_name"
    t.datetime "created_at", null: false
    t.string "currency", null: false
    t.bigint "event_id", null: false
    t.string "payment_for", null: false
    t.integer "quoted_usd_amount_cents"
    t.integer "recipient_country", null: false
    t.string "recipient_email", null: false
    t.text "recipient_information_ciphertext"
    t.string "recipient_name", null: false
    t.text "recipient_phone_number"
    t.text "return_reason"
    t.datetime "sent_at"
    t.datetime "updated_at", null: false
    t.integer "usd_amount_cents"
    t.bigint "user_id", null: false
    t.text "wise_id"
    t.text "wise_recipient_id"
    t.index ["event_id"], name: "index_wise_transfers_on_event_id"
    t.index ["user_id"], name: "index_wise_transfers_on_user_id"
  end

  add_foreign_key "ach_transfers", "events"
  add_foreign_key "ach_transfers", "users", column: "creator_id"
  add_foreign_key "active_storage_attachments", "active_storage_blobs", column: "blob_id"
  add_foreign_key "active_storage_variant_records", "active_storage_blobs", column: "blob_id"
  add_foreign_key "admin_ledger_audit_tasks", "admin_ledger_audits"
  add_foreign_key "admin_ledger_audit_tasks", "hcb_codes"
  add_foreign_key "admin_ledger_audit_tasks", "users", column: "reviewer_id"
  add_foreign_key "announcement_blocks", "announcements"
  add_foreign_key "announcements", "events"
  add_foreign_key "announcements", "users", column: "author_id"
  add_foreign_key "api_tokens", "users"
  add_foreign_key "bank_fees", "events"
  add_foreign_key "canonical_event_mappings", "canonical_transactions"
  add_foreign_key "canonical_event_mappings", "events"
  add_foreign_key "canonical_hashed_mappings", "canonical_transactions"
  add_foreign_key "canonical_hashed_mappings", "hashed_transactions"
  add_foreign_key "canonical_pending_declined_mappings", "canonical_pending_transactions"
  add_foreign_key "canonical_pending_event_mappings", "canonical_pending_transactions"
  add_foreign_key "canonical_pending_event_mappings", "events"
  add_foreign_key "canonical_pending_settled_mappings", "canonical_pending_transactions"
  add_foreign_key "canonical_pending_settled_mappings", "canonical_transactions"
  add_foreign_key "canonical_pending_transactions", "raw_pending_stripe_transactions"
  add_foreign_key "card_grant_pre_authorizations", "card_grants"
  add_foreign_key "card_grant_settings", "events"
  add_foreign_key "card_grants", "events"
  add_foreign_key "card_grants", "stripe_cards"
  add_foreign_key "card_grants", "subledgers"
  add_foreign_key "card_grants", "users"
  add_foreign_key "card_grants", "users", column: "sent_by_id"
  add_foreign_key "check_deposits", "events"
  add_foreign_key "checks", "lob_addresses"
  add_foreign_key "checks", "users", column: "creator_id"
  add_foreign_key "column_account_numbers", "events"
  add_foreign_key "comment_reactions", "comments"
  add_foreign_key "comment_reactions", "users", column: "reactor_id"
  add_foreign_key "contracts", "documents"
  add_foreign_key "disbursements", "events"
  add_foreign_key "disbursements", "events", column: "source_event_id"
  add_foreign_key "disbursements", "transaction_categories", column: "destination_transaction_category_id"
  add_foreign_key "disbursements", "transaction_categories", column: "source_transaction_category_id"
  add_foreign_key "disbursements", "users", column: "fulfilled_by_id"
  add_foreign_key "disbursements", "users", column: "requested_by_id"
  add_foreign_key "discord_messages", "activities"
  add_foreign_key "document_downloads", "documents"
  add_foreign_key "document_downloads", "users"
  add_foreign_key "documents", "events"
  add_foreign_key "documents", "users"
  add_foreign_key "documents", "users", column: "archived_by_id"
  add_foreign_key "donation_goals", "events"
  add_foreign_key "donation_tiers", "events"
  add_foreign_key "donations", "donation_payouts", column: "payout_id"
  add_foreign_key "donations", "events"
  add_foreign_key "donations", "fee_reimbursements"
  add_foreign_key "emburse_card_requests", "emburse_cards"
  add_foreign_key "emburse_card_requests", "events"
  add_foreign_key "emburse_card_requests", "users", column: "creator_id"
  add_foreign_key "emburse_card_requests", "users", column: "fulfilled_by_id"
  add_foreign_key "emburse_cards", "events"
  add_foreign_key "emburse_cards", "users"
  add_foreign_key "emburse_transactions", "emburse_cards"
  add_foreign_key "emburse_transactions", "events"
  add_foreign_key "emburse_transfers", "emburse_cards"
  add_foreign_key "emburse_transfers", "events"
  add_foreign_key "emburse_transfers", "users", column: "creator_id"
  add_foreign_key "emburse_transfers", "users", column: "fulfilled_by_id"
  add_foreign_key "employee_payments", "employees"
  add_foreign_key "employees", "events"
  add_foreign_key "event_affiliations", "events"
  add_foreign_key "event_configurations", "events"
  add_foreign_key "event_follows", "events"
  add_foreign_key "event_follows", "users"
  add_foreign_key "event_group_memberships", "event_groups"
  add_foreign_key "event_group_memberships", "events"
  add_foreign_key "event_groups", "users"
  add_foreign_key "event_plans", "events"
  add_foreign_key "event_scoped_tags", "events", column: "parent_event_id"
  add_foreign_key "event_scoped_tags_events", "event_scoped_tags"
  add_foreign_key "event_scoped_tags_events", "events"
  add_foreign_key "events", "users", column: "point_of_contact_id"
  add_foreign_key "exports", "users", column: "requested_by_id"
  add_foreign_key "fee_relationships", "events"
  add_foreign_key "fees", "canonical_event_mappings"
  add_foreign_key "g_suite_accounts", "g_suites"
  add_foreign_key "g_suite_accounts", "users", column: "creator_id"
  add_foreign_key "g_suite_aliases", "g_suite_accounts"
  add_foreign_key "g_suite_revocations", "g_suites"
  add_foreign_key "g_suites", "events"
  add_foreign_key "g_suites", "users", column: "created_by_id"
  add_foreign_key "governance_admin_transfer_approval_attempts", "governance_admin_transfer_limits"
  add_foreign_key "governance_admin_transfer_approval_attempts", "governance_request_contexts"
  add_foreign_key "governance_admin_transfer_approval_attempts", "users"
  add_foreign_key "governance_admin_transfer_limits", "users"
  add_foreign_key "governance_request_contexts", "users"
  add_foreign_key "governance_request_contexts", "users", column: "impersonator_id"
  add_foreign_key "hashed_transactions", "raw_plaid_transactions"
  add_foreign_key "hcb_code_personal_transactions", "hcb_codes"
  add_foreign_key "hcb_code_personal_transactions", "invoices"
  add_foreign_key "hcb_code_personal_transactions", "users", column: "reporter_id"
  add_foreign_key "hcb_code_pins", "events"
  add_foreign_key "hcb_code_pins", "hcb_codes"
  add_foreign_key "hcb_code_tag_suggestions", "hcb_codes"
  add_foreign_key "hcb_code_tag_suggestions", "tags"
  add_foreign_key "increase_account_numbers", "events"
  add_foreign_key "increase_checks", "events"
  add_foreign_key "increase_checks", "users"
  add_foreign_key "invoices", "fee_reimbursements"
  add_foreign_key "invoices", "invoice_payouts", column: "payout_id"
  add_foreign_key "invoices", "sponsors"
  add_foreign_key "invoices", "users", column: "archived_by_id"
  add_foreign_key "invoices", "users", column: "creator_id"
  add_foreign_key "invoices", "users", column: "manually_marked_as_paid_user_id"
  add_foreign_key "invoices", "users", column: "voided_by_id"
  add_foreign_key "lob_addresses", "events"
  add_foreign_key "login_codes", "users"
  add_foreign_key "mailbox_addresses", "users"
  add_foreign_key "oauth_device_grants", "oauth_applications", column: "application_id"
  add_foreign_key "organizer_position_deletion_requests", "organizer_positions"
  add_foreign_key "organizer_position_deletion_requests", "users", column: "closed_by_id"
  add_foreign_key "organizer_position_deletion_requests", "users", column: "submitted_by_id"
  add_foreign_key "organizer_position_invite_links", "events"
  add_foreign_key "organizer_position_invite_links", "users", column: "creator_id"
  add_foreign_key "organizer_position_invite_links", "users", column: "deactivator_id"
  add_foreign_key "organizer_position_invite_requests", "organizer_position_invite_links"
  add_foreign_key "organizer_position_invite_requests", "organizer_position_invites"
  add_foreign_key "organizer_position_invite_requests", "users", column: "requester_id"
  add_foreign_key "organizer_position_invites", "events"
  add_foreign_key "organizer_position_invites", "organizer_positions"
  add_foreign_key "organizer_position_invites", "users"
  add_foreign_key "organizer_position_invites", "users", column: "sender_id"
  add_foreign_key "organizer_position_spending_control_allowances", "organizer_position_spending_controls"
  add_foreign_key "organizer_position_spending_control_allowances", "users", column: "authorized_by_id"
  add_foreign_key "organizer_position_spending_controls", "organizer_positions"
  add_foreign_key "organizer_positions", "contracts", column: "fiscal_sponsorship_contract_id"
  add_foreign_key "organizer_positions", "events"
  add_foreign_key "organizer_positions", "users"
  add_foreign_key "payment_recipients", "events"
  add_foreign_key "paypal_transfers", "events"
  add_foreign_key "paypal_transfers", "users"
  add_foreign_key "raffles", "users"
  add_foreign_key "raw_pending_incoming_disbursement_transactions", "disbursements"
  add_foreign_key "raw_pending_outgoing_disbursement_transactions", "disbursements"
  add_foreign_key "receipts", "users"
  add_foreign_key "recurring_donations", "events"
  add_foreign_key "referral_attributions", "referral_links"
  add_foreign_key "referral_attributions", "referral_programs"
  add_foreign_key "referral_attributions", "users"
  add_foreign_key "referral_links", "referral_programs", column: "program_id"
  add_foreign_key "referral_links", "users", column: "creator_id"
  add_foreign_key "referral_programs", "users", column: "creator_id"
  add_foreign_key "reimbursement_expense_payouts", "events"
  add_foreign_key "reimbursement_expenses", "reimbursement_reports"
  add_foreign_key "reimbursement_expenses", "users", column: "approved_by_id"
  add_foreign_key "reimbursement_reports", "events"
  add_foreign_key "reimbursement_reports", "users"
  add_foreign_key "reimbursement_reports", "users", column: "invited_by_id"
  add_foreign_key "sponsors", "events"
  add_foreign_key "stripe_authorizations", "stripe_cards"
  add_foreign_key "stripe_card_personalization_designs", "events"
  add_foreign_key "stripe_cardholders", "users"
  add_foreign_key "stripe_cards", "events"
  add_foreign_key "stripe_cards", "stripe_cardholders"
  add_foreign_key "stripe_cards", "users", column: "last_frozen_by_id"
  add_foreign_key "subledgers", "events"
  add_foreign_key "transaction_category_mappings", "transaction_categories"
  add_foreign_key "transactions", "ach_transfers"
  add_foreign_key "transactions", "bank_accounts"
  add_foreign_key "transactions", "checks"
  add_foreign_key "transactions", "disbursements"
  add_foreign_key "transactions", "donation_payouts"
  add_foreign_key "transactions", "emburse_transfers"
  add_foreign_key "transactions", "fee_reimbursements"
  add_foreign_key "transactions", "fee_relationships"
  add_foreign_key "transactions", "invoice_payouts"
  add_foreign_key "user_backup_codes", "users"
  add_foreign_key "user_email_updates", "users"
  add_foreign_key "user_email_updates", "users", column: "updated_by_id"
  add_foreign_key "user_seen_at_histories", "users"
  add_foreign_key "user_sessions", "users"
  add_foreign_key "user_sessions", "users", column: "impersonated_by_id"
  add_foreign_key "w9s", "users", column: "uploaded_by_id"
  add_foreign_key "webauthn_credentials", "users"
  add_foreign_key "wires", "events"
  add_foreign_key "wires", "users"
  add_foreign_key "wise_transfers", "events"
  add_foreign_key "wise_transfers", "users"
  create_function :hcb_code_type, sql_definition: <<-'SQL'
      CREATE OR REPLACE FUNCTION public.hcb_code_type(hcb_code text)
       RETURNS text
       LANGUAGE sql
       IMMUTABLE STRICT
      RETURN CASE split_part(hcb_code, '-'::text, 2) WHEN '000'::text THEN 'unknown'::text WHEN '001'::text THEN 'unknown_temporary'::text WHEN '100'::text THEN 'invoice'::text WHEN '200'::text THEN 'donation'::text WHEN '201'::text THEN 'partner_donation'::text WHEN '300'::text THEN 'ach_transfer'::text WHEN '310'::text THEN 'wire'::text WHEN '350'::text THEN 'paypal_transfer'::text WHEN '360'::text THEN 'wise_transfer'::text WHEN '400'::text THEN 'check'::text WHEN '401'::text THEN 'increase_check'::text WHEN '402'::text THEN 'check_deposit'::text WHEN '500'::text THEN 'disbursement'::text WHEN '550'::text THEN 'incoming_disbursement'::text WHEN '600'::text THEN 'stripe_card'::text WHEN '601'::text THEN 'stripe_force_capture'::text WHEN '610'::text THEN 'stripe_service_fee'::text WHEN '700'::text THEN 'bank_fee'::text WHEN '701'::text THEN 'incoming_bank_fee'::text WHEN '702'::text THEN 'fee_revenue'::text WHEN '710'::text THEN 'expense_payout'::text WHEN '712'::text THEN 'payout_holding'::text WHEN '900'::text THEN 'outgoing_fee_reimbursement'::text ELSE NULL::text END
  SQL

end
