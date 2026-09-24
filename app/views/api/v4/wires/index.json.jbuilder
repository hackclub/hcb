# frozen_string_literal: true

pagination_metadata(json)

json.data @wires, partial: "api/v4/transactions/wire_transfer", as: :wire_transfer
