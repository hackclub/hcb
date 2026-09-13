# frozen_string_literal: true

class ProcessColumnCheckDepositJob < ApplicationJob
  class UnconfidentError < StandardError; end
  class ApiError < StandardError; end
  class MissingParameterError < StandardError; end

  def perform(check_deposit:, validate: true)
    return if check_deposit.column_id.present? || check_deposit.increase_id.present?

    conn = Faraday.new url: "https://api.column.com" do |f|
      f.request :basic_auth, "", Credentials.fetch(:COLUMN, ColumnService::ENVIRONMENT, :API_KEY)
      f.request :multipart
      f.response :raise_error
      f.response :json
    end

    # Upload front
    front = check_deposit.front.open do |file|
      conn.post("/transfers/checks/image/front", { file: Faraday::Multipart::FilePart.new(file.path, check_deposit.front.content_type) }).body
    end

    raise UnconfidentError, "could not confidently parse payment details from check. confidence was #{front["micr_line_confidence"]}" if validate && front["micr_line_confidence"] < 0.8

    # Upload back
    back = check_deposit.back.open do |file|
      conn.post("/transfers/checks/image/back", { file: Faraday::Multipart::FilePart.new(file.path, check_deposit.back.content_type) }).body
    end

    event = check_deposit.event
    account_number = event.column_account_number || event.create_column_account_number

    params = {
      bank_account_id: ColumnService::Accounts::FS_MAIN,
      account_number_id: account_number&.column_id,
      deposited_amount: check_deposit.amount_cents,
      currency_code: "USD",
      micr_line: front["micr_line"],
      image_front: front["image_front"],
      image_back: back["image_back"]
    }

    # Column responds to a missing parameter with a generic "The request is
    # missing a required parameter." Name the parameters ourselves so the error
    # is actionable — `account_number_id` in particular is silently nil when
    # `create_column_account_number` fails its validations.
    missing = params.select { |_, value| value.blank? }.keys
    raise MissingParameterError, missing_parameter_message(missing, account_number) if missing.any?

    column_check_deposit = ColumnService.post("/transfers/checks/deposit", **params, idempotency_key: "check_deposit_#{check_deposit.id}")

    check_deposit.update!(column_id: column_check_deposit["id"], status: :submitted)

    check_deposit.broadcast_replace(target: [check_deposit, :status], partial: "check_deposits/status", locals: { check_deposit: })

    check_deposit

  rescue Faraday::Error, UnconfidentError, MissingParameterError => e
    check_deposit.update!(status: :manual_submission_required)
    Rails.error.unexpected "Check deposit ##{check_deposit.id} needs to be manually submitted to Column."

    case e
    when Faraday::Error then raise ApiError, column_error_message(e)
    when MissingParameterError then raise
    end
  end

  private

  def missing_parameter_message(missing, account_number)
    message = "missing #{missing.to_sentence} for the Column check deposit"
    errors = account_number&.errors&.full_messages

    return message if errors.blank?

    "#{message} (Column account number is invalid: #{errors.to_sentence})"
  end

  # `Faraday::Error#response` is nil for transport-level failures (timeouts,
  # connection resets), and Column doesn't always respond with a JSON body, so
  # fall back to Faraday's own message rather than blowing up with a
  # `NoMethodError` that hides the real failure.
  def column_error_message(error)
    body = error.response_body
    message = (body.is_a?(Hash) ? body["message"] : body).presence || error.message
    url_path = error.response&.dig(:request, :url_path)

    url_path ? "#{message} (#{url_path})" : message
  end

end
