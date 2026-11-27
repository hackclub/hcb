# frozen_string_literal: true

class AddOwnerToOauthApplications < ActiveRecord::Migration[8.1]
  disable_ddl_transaction!

  def change
    add_reference :oauth_applications, :owner, polymorphic: true, index: { algorithm: :concurrently }
  end

end
