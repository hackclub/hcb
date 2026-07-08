# frozen_string_literal: true

class ApplicationPolicy
  attr_reader :user, :record

  def initialize(user, record)
    @user = user
    @record = record
  end

  def index?
    false
  end

  def show?
    false
  end

  def create?
    false
  end

  def new?
    create?
  end

  def update?
    false
  end

  def edit?
    update?
  end

  def destroy?
    false
  end

  def scope
    Pundit.policy_scope!(user, record.class)
  end

  class Scope
    attr_reader :user, :scope

    def initialize(user, scope)
      @user = user
      @scope = scope
    end

    def resolve
      apply_object_grants(visible_scope)
    end

    # Subclasses with custom role-based visibility should override this
    # instead of #resolve, so object-scope grants (see
    # ApiToken::ResourceGrant) are applied uniformly on top regardless of the
    # subclass's own logic. No-op for non-API pundit_users (e.g. the web
    # app's plain User) since they don't carry a token.
    def visible_scope
      scope
    end

    private

    def apply_object_grants(relation)
      token = user.respond_to?(:token) ? user.token : nil
      return relation if token.nil?

      resource_type = relation.klass.api_resource_type
      grants = token.resource_grants_for(:read, resource_type).to_a
      return relation if grants.empty?
      return relation if grants.any? { |grant| grant.scope_root_type.nil? }

      root_pairs = grants.map { |grant| [grant.scope_root_type, grant.scope_root_id] }

      matching_ids = relation.select do |record|
        root_pairs.any? { |type, id| record.api_scope_roots[type] == id }
      end.map(&:id)

      relation.where(id: matching_ids)
    end

  end

end
