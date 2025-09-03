# frozen_string_literal: true

module Partners
  module Google
    module GSuite
      class DeleteUserAlias
        include Partners::Google::GSuite::Shared::DirectoryClient

        def initialize(primary_email:, alias_email:)
          @primary_email = primary_email
          @alias_email = alias_email

        end

        def run
          unless Rails.env.production?
            puts "☣️ In production, we would currently be deleting an alias for a user on GW ☣️"
            return
          end

          begin
            # Checks that a user exists with the provided primary email
            Partners::Google::GSuite::User.new(email: @primary_email).run
            # Raises if users is not found
          rescue ::Google::Apis::ClientError
            throw :abort
          end

          begin
            # Deletes the user alias
            directory_client.delete_user_alias(@primary_email, @alias_email)
          rescue ::Google::Apis::ClientError
            throw :abort
          end
          true
        end

      end
    end
  end
end
