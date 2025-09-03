# frozen_string_literal: true

module Partners
  module Google
    module GSuite
      class CreateUserAlias
        include Partners::Google::GSuite::Shared::DirectoryClient

        def initialize(primary_email:, alias_email:)
          @primary_email = primary_email
          @alias_email = alias_email

        end

        def run
          unless Rails.env.production?
            puts "☣️ In production, we would currently be creating an alias for a user on GW ☣️"
            return
          end

          begin
            # Checks that a user exists with the provided primary email
            Partners::Google::GSuite::User.new(email: @primary_email).run
          rescue ::Google::Apis::ClientError
            # Raises if user was not found
            throw :abort
          end

          begin
            # Creates the user alias
            directory_client.insert_user_alias(@primary_email, user_alias_object)
          rescue ::Google::Apis::ClientError
            throw :abort
          end
          true
        end

        private

        def user_alias_object
          ::Google::Apis::AdminDirectoryV1::Alias.new(
            alias: @alias_email
          )
        end

      end
    end
  end
end
