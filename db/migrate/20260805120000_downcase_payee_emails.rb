# frozen_string_literal: true

class DowncasePayeeEmails < ActiveRecord::Migration[8.1]
  disable_ddl_transaction!

  def up
    Payee.where("email <> lower(btrim(email))").in_batches(of: 1_000) do |batch|
      batch.update_all("email = lower(btrim(email))")
    end
  end

  def down
    # Irreversible: the original casing isn't recoverable.
  end

end
