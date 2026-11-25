# frozen_string_literal: true

class RemoveUseSmsAuthFromUsers < ActiveRecord::Migration[8.1]
  def change
    # "Prefer login codes via SMS" stopped steering the login flow when logins
    # started replaying the factors from the previous login (#11920). The
    # setting and its last reader were removed and User ignores the column.
    safety_assured do
      remove_column :users, :use_sms_auth, :boolean, default: false
    end
  end

end
