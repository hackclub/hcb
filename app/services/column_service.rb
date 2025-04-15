# frozen_string_literal: true

class ColumnService
  ENVIRONMENT = Rails.env.production? ? :production : :sandbox

  module Accounts
    FS_MAIN = Credentials.fetch(:COLUMN, ENVIRONMENT, :fs_main_account_id)
    FS_OPERATING = Credentials.fetch(:COLUMN, ENVIRONMENT, :fs_operating_account_id)

    def self.id_of(account_sym)
      const_get(account_sym.upcase)
    rescue
      raise ArgumentError, "unknown Column account: #{account_sym.inspect}"
    end
  end

  module AchCodes
    INSUFFICIENT_BALANCE = "R01"
    STOP_PAYMENT = "R08"
  end

  def self.conn
    @conn ||= Faraday.new url: "https://api.column.com" do |f|
      f.request :basic_auth, "", Credentials.fetch(:COLUMN, ColumnService::ENVIRONMENT, :API_KEY)
      f.request :url_encoded
      f.response :raise_error
      f.response :json
    end
  end

  def self.get(url, params = {})
    conn.get(url, params).body
  end

  def self.post(url, params = {})
    raise ArgumentError, "missing idempotency_key: #{url}" if params[:idempotency_key].nil?

    idempotency_key = params.delete(:idempotency_key)
    conn.post(url, params, { "Idempotency-Key" => idempotency_key }.compact_blank).body
  end

  def self.transactions(from_date: 1.week.ago, to_date: Date.today, bank_account: Accounts::FS_MAIN)
    # 1: fetch daily reports from Column
    reports = get(
      "/reporting",
      type: "bank_account_transaction",
      limit: 100,
      from_date: from_date.to_date.iso8601,
      to_date: to_date.to_date.iso8601,
    )["reports"].select { |r| r["from_date"] == r["to_date"] && r["row_count"]&.>(0) }

    document_ids = reports.pluck "json_document_id"

    dates = reports.pluck "from_date"

    # if (from_date.to_date..to_date.to_date).reject { |date| dates.include?(date.to_date.iso8601) }.any?
    #  raise StandardError.new("Missing Column reports for #{from_date.to_date.iso8601} to #{to_date.to_date.iso8601}")
    # end

    reports.to_h do |report|
      url = get("/documents/#{report["json_document_id"]}")["url"]
      transactions = JSON.parse(Faraday.get(url).body).select { |t| t["bank_account_id"] == bank_account && t["available_amount"].present? && t["available_amount"] != 0 }

      [report["id"], transactions]
    end
  end

  def self.schedule_bank_account_summary_report(from_date: 1.month.ago, to_date: Date.today)
    post(
      "/reporting",
      type: "bank_account_summary",
      from_date: from_date.to_date.iso8601,
      to_date: to_date.to_date.iso8601,
    )
  end

  def self.bank_account_summary_report(from_date: 1.month.ago, to_date: Date.today)
    reports = ColumnService.get(
      "/reporting",
      type: "bank_account_summary",
      limit: 100,
      from_date: from_date.to_date.iso8601,
      to_date: to_date.to_date.iso8601,
    )["reports"].select { |r| r["from_date"] == from_date.to_date.iso8601 && r["to_date"] == to_date.to_date.iso8601 && r["row_count"]&.>(0) }

    return reports.first
  end

  def self.bank_account_summary_report_url(from_date: 1.month.ago, to_date: Date.today)
    if report = bank_account_summary_report(from_date:, to_date:)
      return get("/documents/#{report["csv_document_id"]}")["url"]
    else
      schedule_bank_account_summary_report(from_date:, to_date:)
      return nil
    end
  end

  def self.balance_over_time(from_date: 1.month.ago, to_date: Date.today, bank_account: Accounts::FS_MAIN)
    if report = bank_account_summary_report(from_date:, to_date:)
      url = get("/documents/#{report["json_document_id"]}")["url"]
      account = JSON.parse(Faraday.get(url).body).select { |t| t["bank_account_id"] == bank_account }.first
      return { starting: account["available_balance_open"], closing: account["available_balance_close"] }
    else
      return { starting: nil, closing: nil }
    end
  end

  def self.ach_transfer(id)
    get("/transfers/ach/#{id}")
  end

  def self.return_ach(id, with:)
    post("/transfers/ach/#{id}/return", return_code: with, idempotency_key: "#{id}_return")
  end

end
