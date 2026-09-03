# frozen_string_literal: true

# Seed one Grant per existing grant: pointing at the reimbursement report if the
# grant was accepted as a reimbursement, otherwise at the card grant itself.
# Runs after the converted-status backfill so `converted_to_reimbursement?` is set.
class BackfillGrants < ActiveRecord::Migration[8.1]
  def up
    CardGrant.find_each(batch_size: 1000) do |card_grant|
      if card_grant.converted_to_reimbursement? && card_grant.reimbursement_report.present?
        report = card_grant.reimbursement_report
        next if Grant.exists?(grantable: report)

        Grant.create!(event: card_grant.event, user: card_grant.user, sent_by: card_grant.sent_by,
                      grantable: report, aasm_state: "accepted_with_reimbursement")
      else
        next if Grant.exists?(grantable: card_grant)

        Grant.create!(event: card_grant.event, user: card_grant.user, sent_by: card_grant.sent_by,
                      grantable: card_grant, aasm_state: grant_state_for(card_grant))
      end
    end
  end

  def down
    Grant.delete_all
  end

  private

  def grant_state_for(card_grant)
    return "canceled" if card_grant.canceled?
    return "expired" if card_grant.expired?
    return "accepted_with_card" if card_grant.stripe_card_id.present?

    "pending"
  end

end
