# frozen_string_literal: true

class ApplicationPolicy
  attr_reader :user, :record

  # ApiAdminContext#for_record binds the record being authorized, so bare
  # user.admin?/user.auditor? calls honor resource-limited admin access.
  def initialize(user, record)
    @user = user.respond_to?(:for_record) ? user.for_record(record) : user
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
      @user = user.respond_to?(:for_record) ? user.for_record(scope) : user
      @scope = scope
    end

    def resolve
      apply_object_grants(visible_scope)
    end

    def visible_scope
      scope
    end

    private

    def apply_object_grants(relation)
      token = user.respond_to?(:token) ? user.token : nil
      return relation if token.nil?

      relation = relation.all
      grants = token.resource_grants_for(:read, relation.klass.api_resource_type).to_a
      return relation if grants.empty? || grants.any? { |grant| grant.scope_root_type.nil? }

      relation.where(id: relation.select { |record| grants.any? { |grant| grant.covers?(record) } }.map(&:id))
    end

  end

end
