class EventDropSponsorshipFee < ActiveRecord::Migration[7.2]
  def change
    safety_assured do
      remove_column :events, :sponsorship_fee, :decimal
    end
  end
end
