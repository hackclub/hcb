# frozen_string_literal: true

pagination_metadata(json)

json.data @timeline_items do |item|
  if item.is_a?(Comment)
    json.id item.public_id
    json.object "comment"
    json.type "comment"
    json.content item.content
    json.actor item.user, partial: "api/v4/users/user", as: :user
    json.file rails_blob_url(item.file) if item.file.attached?
    json.admin_only item.admin_only?
    json.created_at item.created_at
  else
    state = item.changeset["aasm_state"]&.second
    previous_state = item.changeset["aasm_state"]&.first
    actor = @timeline_actors[item.whodunnit.to_i]

    message = if state
                if state == "draft" && previous_state.nil?
                  if @report.card_grant.present?
                    "converted a card grant into this draft report"
                  elsif @report.user != actor
                    "invited #{@report.user.initial_name} to this draft report"
                  else
                    "created this draft report"
                  end
                else
                  case state
                  when "submitted"               then "submitted this report"
                  when "rejected"                then "rejected this report"
                  when "reimbursement_requested" then "approved this report"
                  when "reimbursement_approved"  then "approved this report on behalf of the HCB team"
                  when "draft"                   then "converted this report to a draft"
                  when "reimbursed"              then "initiated a #{@report.transfer_text} to #{@report.user.name}"
                  when "reversed"                then "canceled this reimbursement"
                  end
                end
              else
                "#{item.event}d this report"
              end

    json.id "ver_#{item.id}"
    json.object "timeline_event"
    json.type state ? "state_change" : "report_update"
    json.status state
    json.message message
    json.actor do
      if actor
        json.partial! "api/v4/users/user", user: actor
      else
        json.nil!
      end
    end
    json.created_at item.created_at
  end
end
