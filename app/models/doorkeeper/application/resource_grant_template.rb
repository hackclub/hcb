# frozen_string_literal: true

# == Schema Information
#
# Table name: doorkeeper_application_resource_grant_templates
#
#  id              :bigint           not null, primary key
#  access_level    :string           not null
#  resource_type   :string           not null
#  scope_root_type :string
#  created_at      :datetime         not null
#  updated_at      :datetime         not null
#  application_id  :bigint           not null
#  scope_root_id   :bigint
#
# Indexes
#
#  idx_on_application_id_6a05b5aba9  (application_id)
#
# Foreign Keys
#
#  fk_rails_...  (application_id => oauth_applications.id)
#
class Doorkeeper::Application::ResourceGrantTemplate < ApplicationRecord
  self.table_name = "doorkeeper_application_resource_grant_templates"

  include ResourceGrantable

  belongs_to :application, class_name: "Doorkeeper::Application"

end
