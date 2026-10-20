# frozen_string_literal: true

class AddImpersonatedByIdToVersions < ActiveRecord::Migration[8.1]
  def change
    add_column :versions, :impersonated_by_id, :bigint
  end

end
