# frozen_string_literal: true

Grape::Kaminari::MaxValueValidator.class_eval do
  def validate_param!(attr_name, params)
    attr = params[attr_name]
    return unless attr.is_a?(Integer) && @options && attr > @options

    raise Grape::Exceptions::Validation.new(
      params: [@scope.full_name(attr_name)],
      message: "must be less than or equal #{@options}"
    )
  end
end
