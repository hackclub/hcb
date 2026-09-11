# frozen_string_literal: true

module Api
  module V5
    # Index and show for a resource that is an ordinary relation scoped by a
    # Pundit `Scope`, optionally narrowed to one organization.
    #
    # Every v5 read index has the same shape — `policy_scope`, an optional
    # organization filter, cursor pagination — and the differences that used to
    # justify hand-written controllers (which parent to authorize, whether to
    # `skip_authorization`) are exactly what this port removed. Writing it once
    # means a new resource cannot quietly reintroduce one of them.
    module ScopedResource
      extend ActiveSupport::Concern

      class_methods do
        # `model` is the record class; `organization_scope` names how the model
        # reaches its organization, for the `organization_id` filter.
        def scoped_resource(model, organization_scope: :event, order: { created_at: :desc }, preload: [])
          @scoped_model = model
          @scoped_organization_scope = organization_scope
          @scoped_order = order
          @scoped_preload = preload
        end

        attr_reader :scoped_model, :scoped_organization_scope, :scoped_order, :scoped_preload
      end

      def index
        records = policy_scope(self.class.scoped_model)
        records = records.preload(*self.class.scoped_preload) if self.class.scoped_preload.present?
        records = records.order(**self.class.scoped_order)
        records = narrow_to_organization(records) if params[:organization_id].present?

        @records = paginate_cursor(records.to_a, &:public_id)
      end

      def show
        @record = authorize self.class.scoped_model.find_by_public_id!(params[:id]), :show_any_attribute?
      end

      private

      # Narrowing can only ever reduce what `policy_scope` already allowed, so
      # an organization the viewer cannot read yields an empty page rather than
      # a 403 that would confirm it exists. `where_public_id` avoids loading the
      # organization row just to read its id.
      def narrow_to_organization(records)
        events = Event.where_public_id(params[:organization_id]).or(Event.where(slug: params[:organization_id]))

        case self.class.scoped_organization_scope
        when :event    then records.where(event: events)
        when :sponsor  then records.where(sponsor: Sponsor.where(event: events))
        when :either_end then records.where(source_event: events).or(records.where(destination_event: events))
        else raise ArgumentError, "unknown organization scope #{self.class.scoped_organization_scope}"
        end
      end

    end
  end
end
