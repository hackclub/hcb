# frozen_string_literal: true

module Maintenance
  class DowncasePayeeEmailsTask < MaintenanceTasks::Task
    def collection
      Payee.where("email <> lower(btrim(email))")
    end

    def process(payee)
      payee.update!(email: payee.email)
    end

  end
end
