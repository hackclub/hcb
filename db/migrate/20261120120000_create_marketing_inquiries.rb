# frozen_string_literal: true

class CreateMarketingInquiries < ActiveRecord::Migration[8.1]
  def change
    create_table :marketing_inquiries do |t|
      t.string :page, null: false
      t.string :audience
      t.string :name
      t.string :email, null: false
      t.text :message
      t.string :ref
      t.timestamps
    end
    add_index :marketing_inquiries, [:page, :created_at]
  end

end
