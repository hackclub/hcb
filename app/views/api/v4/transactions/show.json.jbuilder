# frozen_string_literal: true

expand((:organization if params[:event_id].blank?)) do
  json.partial! "transaction", tx: @hcb_code
end
