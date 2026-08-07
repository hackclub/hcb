# frozen_string_literal: true

ActiveSupport.on_load(:active_record) do
  Hashid::Rails::ClassMethods.module_eval do
    def hashid_configuration
      if is_a?(ActiveRecord::Relation) && klass.respond_to?(:hashid_configuration)
        klass.hashid_configuration
      else
        @hashid_configuration || hashid_config
      end
    end
  end
end

Hashid::Rails.configure do |config|
  config.salt = Credentials.fetch(:HASHID_SALT)
end
