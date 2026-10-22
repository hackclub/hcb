# frozen_string_literal: true

module GSuiteAccountService
  class Create
    def initialize(g_suite:, current_user:,
                   backup_email:, address:, first_name:, last_name:)
      @g_suite = g_suite
      @current_user = current_user

      @backup_email = backup_email
      @address = address.to_s.strip
      @first_name = first_name
      @last_name = last_name
    end

    def run
      ActiveRecord::Base.transaction do
        # 1. Create local account
        g_suite_account.save!

        # 2. Create remote org unit if does not exist already and assign identifiers locally
        @g_suite.update_column(:remote_org_unit_id, remote_org_unit_id)
        @g_suite.update_column(:remote_org_unit_path, remote_org_unit_path)

        # 3. create remote user under org unit
        Partners::Google::GSuite::CreateUser.new(**remote_account_attrs).run

        # 4. Send notification
        GSuiteAccountMailer.notify_user_of_activation(email_params).deliver_later

        # 5. return g_suite_account
        g_suite_account
      end
    end

    private

    def full_email_address
      "#{@address}@#{domain}"
    end

    def domain
      @g_suite.domain
    end

    def g_suite_account
      @g_suite_account ||= @g_suite.accounts.new(local_account_attrs)
    end

    def local_account_attrs
      {
        backup_email: @backup_email,
        address: full_email_address,
        first_name: @first_name,
        last_name: @last_name,
        creator: @current_user,
        initial_password: temporary_password,
        accepted_at: DateTime.now
      }
    end

    def temporary_password
      @temporary_password ||= SecureRandom.hex(6)
    end

    def remote_org_unit
      @remote_org_unit ||= GSuiteService::FindOrCreateRemoteOrgUnit.new(g_suite: @g_suite).run
    end

    def remote_org_unit_id
      remote_org_unit.org_unit_id
    end

    def remote_org_unit_path
      remote_org_unit.org_unit_path
    end

    def remote_account_attrs
      {
        given_name: @first_name,
        family_name: @last_name,
        password: temporary_password,
        primary_email: full_email_address,
        recovery_email: @backup_email,

        org_unit_path: remote_org_unit_path
      }
    end

    def email_params
      {
        recipient: @backup_email,
        address: full_email_address,
        password: temporary_password,
        event: @g_suite.event.name
      }
    end

  end
end
