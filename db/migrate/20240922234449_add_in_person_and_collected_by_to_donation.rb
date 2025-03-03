class AddInPersonAndCollectedByToDonation < ActiveRecord::Migration[7.2]
  def change
    add_column :donations, :in_person, :boolean, default: false
    add_column :donations, :collected_by_id, :bigint
  end
end
