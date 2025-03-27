# frozen_string_literal: true

module Api
  class Directory < Grape::API
    include Grape::Kaminari

    desc "Endpoints for HCB directory" do
      hidden true # Don't list endpoints in OpenAPI spec/docs
    end
    namespace "directory" do
      params do
        use :pagination, per_page: 50, max_per_page: 100
      end
      get :organizations do
        orgs = Event.indexable.includes(:event_tags).where(event_tags: { name: [EventTag::Tags::HACKATHON, EventTag::Tags::ROBOTICS_TEAM] })
                    .or(
                      # Tagged as okay to list in the Climate Directory
                      Event.includes(:event_tags).where({ event_tags: { name: EventTag::Tags::CLIMATE, purpose: :directory } }),
                    )
        orgs = Event.where(id: orgs.select(:id))
                    .includes(:event_tags)
                    .with_attached_logo.with_attached_background_image

        @organizations = paginate(orgs.reorder(name: :asc))

        present @organizations, with: Api::Entities::DirectoryOrganization
      end
    end

  end
end
