class AddElectronicConsentToLegalEntity < ActiveRecord::Migration[8.1]
  def change
    add_column :legal_entities, :electronic_consent, :boolean
    add_column :legal_entities, :electronic_consent_at, :datetime
  end
end
