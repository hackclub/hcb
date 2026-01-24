# frozen_string_literal: true

module Api
  module V4
    module ErrorHandling
      extend ActiveSupport::Concern

      included do
        rescue_from Pundit::NotAuthorizedError do
          render json: { error: "not_authorized" }, status: :forbidden
        end

        rescue_from ActiveRecord::RecordNotFound do |e|
          render json: { error: "resource_not_found", messages: [("Couldn't locate that #{e.model.constantize.model_name.human}." if e.model)] }.compact_blank, status: :not_found
        end

        rescue_from ActiveRecord::RecordInvalid do |e|
          render json: { error: "invalid_record", messages: e.record.errors.full_messages }, status: :bad_request
        end

        rescue_from ActiveRecord::RecordNotSaved do |e|
          messages = if e.respond_to?(:record) && e.record.respond_to?(:errors)
                       e.record.errors.full_messages
                     else
                       ["Record could not be saved"]
                     end
          render json: { error: "invalid_operation", messages: messages }, status: :bad_request
        end

        rescue_from ArgumentError, ActiveRecord::UnknownAttributeError, ActiveRecord::ReadOnlyRecord do |e|
          render json: { error: "invalid_operation", messages: [e.message] }, status: :bad_request
        end

        rescue_from Stripe::InvalidRequestError, Errors::StripeInvalidNameError do |e|
          render json: { error: "stripe_error", messages: [e.message] }, status: :bad_request
        end

        rescue_from ActiveRecord::ConnectionNotEstablished, ActiveRecord::DatabaseConnectionError do
          render json: { error: "service_unavailable", messages: ["Database unavailable"] }, status: :service_unavailable
        end

        rescue_from ActiveRecord::ActiveRecordError do
          render json: { error: "internal_error", messages: ["Internal database error"] }, status: :internal_server_error
        end
      end
    end
  end
end
