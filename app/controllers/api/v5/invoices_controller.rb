# frozen_string_literal: true

module Api
  module V5
    class InvoicesController < ApplicationController
      include Api::V5::ScopedResource

      scoped_resource Invoice, organization_scope: :sponsor, preload: [:event]
    end
  end
end
