# frozen_string_literal: true

# == Schema Information
#
# Table name: column_statements
#
#  id               :bigint           not null, primary key
#  closing_balance  :integer
#  end_date         :datetime
#  start_date       :datetime
#  starting_balance :integer
#  created_at       :datetime         not null
#  updated_at       :datetime         not null
#
module Column
  class Statement < ApplicationRecord
    has_one_attached :file
    validates :file, attached: true


  end
end
