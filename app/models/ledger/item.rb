# frozen_string_literal: true

class Ledger
  class Item < ApplicationRecord
    include Hashid::Rails
    hashid_config salt: Credentials.fetch(:HASHID_SALT)

  end

end
