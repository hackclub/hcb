# frozen_string_literal: true

class FlipLcrTransactionReference < ActiveRecord::Migration[5.2]
  def change
    remove_reference :load_card_requests, :transact_son
    add_reference :transact_so_ns, :load_card_request, foreign_key: true
  end

end
