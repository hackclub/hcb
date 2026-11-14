# frozen_string_literal: true

class ApplicationPolicy
  attr_reader :user, :record

  class_attribute :field_rules, instance_accessor: false, default: {}.freeze

  # Guards fields on the record that need more than access to the record
  # itself. While a response renders, reading one of them checks `if:`, a
  # predicate on this policy, for the viewer. See FieldGuard.
  #
  #   fields :front, :back, if: :view_image?
  def self.fields(*names, **options)
    rule = options.fetch(:if)
    names = names.map(&:to_sym)
    self.field_rules = field_rules.merge(names.index_with(rule)).freeze
    FieldGuard.install(guarded_model, names)
  end

  # The model whose fields this policy guards: EventPolicy guards Event.
  def self.guarded_model
    name.delete_suffix("Policy").constantize
  end

  def initialize(user, record)
    @user = user
    @record = record
  end

  # Whether the viewer may read `field`. Fields without a rule follow access
  # to the record itself, which `authorize` already checked.
  def readable_field?(field)
    rule = self.class.field_rules[field.to_sym]
    rule.nil? || send(rule)
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
      scope
    end

  end

end
