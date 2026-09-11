# frozen_string_literal: true

json.array! @ach_transfers, partial: "api/v5/transactions/ach_transfer", as: :ach_transfer
