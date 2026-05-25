# frozen_string_literal: true

# == Schema Information
#
# Table name: governance_request_contexts
#
#  id                          :bigint           not null, primary key
#  action_name                 :string           not null
#  authentication_session_type :string           not null
#  controller_name             :string           not null
#  http_method                 :string           not null
#  ip_address                  :inet             not null
#  occurred_at                 :datetime         not null
#  path                        :string           not null
#  user_agent                  :string           not null
#  created_at                  :datetime         not null
#  updated_at                  :datetime         not null
#  authentication_session_id   :bigint           not null
#  impersonator_id             :bigint
#  request_id                  :string           not null
#  user_id                     :bigint           not null
#
# Indexes
#
#  index_governance_request_contexts_on_authentication_session  (authentication_session_type,authentication_session_id)
#  index_governance_request_contexts_on_impersonator_id         (impersonator_id)
#  index_governance_request_contexts_on_ip_address              (ip_address)
#  index_governance_request_contexts_on_request_id              (request_id) UNIQUE
#  index_governance_request_contexts_on_user_id                 (user_id)
#
# Foreign Keys
#
#  fk_rails_...  (impersonator_id => users.id)
#  fk_rails_...  (user_id => users.id)
#
module Governance
  class RequestContext < ApplicationRecord
    belongs_to :user
    belongs_to :impersonator, class_name: "User", optional: true
    belongs_to :authentication_session, polymorphic: true

    validates :request_id, :ip_address, :user_agent, :controller_name, :action_name, :http_method, :path, :occurred_at, presence: true
    validates :request_id, uniqueness: true
    validate :authentication_session_is_user_session

    def self.from_controller(controller_instance)
      Governance::RequestContext.new(
        # App-specific methods that must be defined in the controller
        user: controller_instance.current_user,
        impersonator: controller_instance.current_session&.impersonated_by,
        authentication_session: controller_instance.current_session,

        # Generic Rails stuff
        request_id: controller_instance.request.uuid,
        ip_address: controller_instance.request.remote_ip,
        user_agent: controller_instance.request.user_agent,
        controller_name: controller_instance.controller_name,
        action_name: controller_instance.action_name,
        http_method: controller_instance.request.method,
        path: controller_instance.request.fullpath,
        occurred_at: Time.current
      )
    end

    def impersonated? = impersonator.present?

    private

    def authentication_session_is_user_session
      # authentication_session was made polymorphic to potentially support
      # tracking API requests in the future, but for now we only want User::Session.
      unless authentication_session.is_a?(User::Session)
        errors.add(:authentication_session, "must be a User::Session")
      end
    end

  end
end
