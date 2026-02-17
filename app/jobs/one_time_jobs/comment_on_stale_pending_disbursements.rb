# frozen_string_literal: true

module OneTimeJobs
  class CommentOnStalePendingDisbursements
    def self.perform
      disbursements = Disbursement.where(aasm_state: "pending")
                                  .where("pending_at <= ?", 2.days.ago)
                                  .order(created_at: :desc)
                                  .limit(1000)

      disbursements.find_each do |disbursement|
        disbursement.local_hcb_code.comments.build({
                                                     content: "Hi there! This automated comment is from the HCB team. We've updated our transfer processing system, which means this transaction's date in your account will change. Your balance and spending limits remain completely unchanged. If you have any questions, email us at hcb [at] hackclub [dot] com.",
                                                     user: User.system_user
                                                   }).save
      end
    end

  end
end
