# frozen_string_literal: true

# == Schema Information
#
# Table name: exports
#
#  id              :bigint           not null, primary key
#  parameters      :jsonb
#  type            :text
#  created_at      :datetime         not null
#  updated_at      :datetime         not null
#  requested_by_id :bigint
#
# Indexes
#
#  index_exports_on_requested_by_id  (requested_by_id)
#
# Foreign Keys
#
#  fk_rails_...  (requested_by_id => users.id)
#
class Export < ApplicationRecord
  belongs_to :requested_by, class_name: "User", optional: true
  validates_presence_of :requested_by, if: -> { async? }

  self.abstract_class = true

  # returns true / false, whether or not the export has to be done
  # asynchronously and emailed to the user or not.
  def async?
    raise UnimplementedError
  end

  # label to use when emailing user w/ export
  def label
    raise UnimplementedError
  end

  def filename
    raise UnimplementedError
  end

  def mime_type
    raise UnimplementedError
  end

  def content
    raise UnimplementedError
  end


end
