# frozen_string_literal: true

# be careful before running this job!
# this job will look for transactions before "date" from "user"
# and mark all the transactions missing a receipt as lost
# it'll leave a comment to serve as a paper trail.

module OneTimeJobs
  class BackfillLostReceipts
    def self.perform(user, date)
      user.transactions_missing_receipt.find_each do |txn|
        if txn.created_at < date
          txn.no_or_lost_receipt!
          txn.comments.build({
                               content: "The receipts for this transaction were marked as lost/missing automatically.",
                               user: User.system_user
                             }).save
        end
      end
    end

  end
end
