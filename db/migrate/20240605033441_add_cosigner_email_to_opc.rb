class AddCosignerEmailToOpc < ActiveRecord::Migration[7.1]
  def change
    add_column :organizer_position_contracts, :cosigner_email, :string
  end
end
