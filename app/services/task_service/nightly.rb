module TaskService
  class Nightly
    def initialize
      @tasks = Task::Receiptable::Upload.incomplete
      @hcb_codes_without_task = HcbCode.receipt_required.where.not(id: Task::Receiptable::Upload.select(:taskable_id))
    end

    def run
      puts "starting nightly task service"

      ensure_tasks_exist
      update_task_completion
      check_for_parity
    end

    def ensure_tasks_exist
      count = @hcb_codes_without_task.count
      i = 0

      @hcb_codes_without_task.find_each(batch_size: 100) do |hcb_code|
        hcb_code.ensure_task_exists!
        i += 1
        puts "Processed HCB Code #{i} of #{count}" if i % 100 == 0
      end
    end

    def update_task_completion
      count = @tasks.count
      i = 0

      @tasks.find_each(batch_size: 100) do |task|
        task.update_complete!
        i += 1
        puts "Updated Task #{i} of #{count}" if i % 100 == 0
      end
    end

    def check_for_parity
      count = User.count
      i = 0

      User.find_each(batch_size: 100) do |user|
        old = user.transactions_missing_receipt
        current = user.transactions_missing_receipt_v2

        if old.count != current.count
          Airbrake.notify("User #{user.id} has #{old.count} old, but #{current.count} new")
        end

        i += 1

        puts "Checked User #{i} of #{count}" if i % 100 == 0
      end
    end

  end
end
