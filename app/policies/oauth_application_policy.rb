# frozen_string_literal: true

class OauthApplicationPolicy < ApplicationPolicy
  def revoke_tokens?
    user&.admin?
  end

end
