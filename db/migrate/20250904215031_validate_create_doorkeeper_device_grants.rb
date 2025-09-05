class ValidateCreateDoorkeeperDeviceGrants < ActiveRecord::Migration[7.2]
  def change
    validate_foreign_key :oauth_device_grants, :oauth_applications
  end
end