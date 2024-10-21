# frozen_string_literal: true

class AddAasmToPartneredSignup < ActiveRecord::Migration[6.0]
  def up
    add_column :partnered_signups, :aasm_state, :string
    add_column :partnered_signups, :applicant_signed_at, :datetime
    add_column :partnered_signups, :completed_at, :datetime

    # Migrate existing data
    # PartneredSignup.all.each do |sup|
    #  if sup.rejected_at.present?
    #    sup.aasm_state = "rejected"
    #  elsif sup.accepted_at.present?
    #    sup.aasm_state = "completed"
    #  elsif sup.submitted_at.present?
    #    sup.aasm_state = "submitted"
    #  else
    #    sup.aasm_state = "unsubmitted"
    #  end
    #  sup.save
    # end
  end

  def down
    remove_column :partnered_signups, :aasm_state, :string
    remove_column :partnered_signups, :applicant_signed_at, :datetime
    remove_column :partnered_signups, :completed_at, :datetime
  end

end
