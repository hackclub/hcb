# frozen_string_literal: true

module GSuiteService
  class Update
    def initialize(g_suite_id:, domain:, verification_key:, dkim_key: nil)
      @g_suite_id = g_suite_id

      @domain = domain
      @verification_key = verification_key.nil? ? g_suite.verification_key : verification_key
      @dkim_key = dkim_key.nil? ? g_suite.dkim_key : dkim_key
    end

    def run
      ActiveRecord::Base.transaction do
        domain_changing?
        verification_key_changing?

        g_suite.domain = @domain
        g_suite.verification_key = smart_verification_key
        g_suite.dkim_key = @dkim_key
        g_suite.save!

        if domain_changing?
          g_suite.mark_creating!

          ::Partners::Google::GSuite::DeleteDomain.new(domain: @domain).run
          ::Partners::Google::GSuite::CreateDomain.new(domain: @domain).run

          notify_operations
        elsif verification_key_changing?
          g_suite.mark_configuring!

          notify_of_configuring
        end

        g_suite
      end
    end

    private

    def notify_operations
      GSuiteMailer.with(g_suite_id: g_suite.id).notify_operations_of_entering_created_state.deliver_now
    end

    def notify_of_configuring
      GSuiteMailer.with(g_suite_id: g_suite.id).notify_of_configuring.deliver_now if g_suite.created_by.present?
    end

    def g_suite
      @g_suite ||= ::GSuite.find(@g_suite_id)
    end

    def domain_changing?
      @domain_changing ||= g_suite.domain != @domain
    end

    def verification_key_changing?
      @verification_key_changing ||= g_suite.verification_key != @verification_key
    end

    def smart_verification_key
      @smart_verification_key ||= domain_changing? ? nil : @verification_key
    end

  end
end
