# frozen_string_literal: true

expand((:organization if params[:event_id].blank?)) do
  json.partial! "api/v4/transactions/transaction", tx: @hcb_code
end
