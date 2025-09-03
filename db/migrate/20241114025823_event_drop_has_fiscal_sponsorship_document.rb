class EventDropHasFiscalSponsorshipDocument < ActiveRecord::Migration[7.2]
  def change
    safety_assured do
      remove_column :events, :has_fiscal_sponsorship_document, :boolean
    end
  end
end
