class AddCosignerEmailToEventApplication < ActiveRecord::Migration[8.0]
  def change
    add_column :event_applications, :cosigner_email, :string
  end
end
