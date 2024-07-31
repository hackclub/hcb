# frozen_string_literal: true

class RemovePartnerDocusignSupport < ActiveRecord::Migration[7.0]
  def change
    safety_assured do
      remove_column :partnered_signups, :docusign_envelope_id, :string
      remove_column :partnered_signups, :signed_contract, :boolean
      remove_column :partners, :docusign_template_id, :string
    end
  end

end
