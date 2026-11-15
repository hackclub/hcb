class AddRedirectToToReferralPrograms < ActiveRecord::Migration[8.0]
  def change
    add_column :referral_programs, :redirect_to, :string
  end
end
