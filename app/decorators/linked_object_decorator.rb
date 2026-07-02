# frozen_string_literal: true

class LinkedObjectDecorator < SimpleDelegator
  def author
    # This method should be overwritten in specific classes
    raise NotImplementedError, "The #{self.class.name} model inherits from LinkedObjectDecorator, but hasn't implemented it's own version of author."
  end
end
