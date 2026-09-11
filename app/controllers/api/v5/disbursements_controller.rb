# frozen_string_literal: true

module Api
  module V5
    class DisbursementsController < ApplicationController
      include Api::V5::ScopedResource

      scoped_resource Disbursement, organization_scope: :either_end, preload: [:event]
    end
  end
end
