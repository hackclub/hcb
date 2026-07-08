# frozen_string_literal: true

# == Schema Information
#
# Table name: tours
#
#  id            :bigint           not null, primary key
#  active        :boolean          default(TRUE)
#  name          :string
#  step          :integer          default(0)
#  tourable_type :string           not null
#  created_at    :datetime         not null
#  updated_at    :datetime         not null
#  tourable_id   :bigint           not null
#
class Tour < ApplicationRecord
  default_scope { where(active: true) }

  belongs_to :tourable, polymorphic: true

end
