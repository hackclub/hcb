# frozen_string_literal: true

class AddAuthorizationMethodToCardCharges < ActiveRecord::Migration[8.1]
  def change
    add_column :card_charges, :authorization_method, :string
  end

end
