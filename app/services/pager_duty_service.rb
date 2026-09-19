# frozen_string_literal: true

# Sends events to PagerDuty's Events API v2.
#
# An event is addressed to a PagerDuty *service* by that service's integration
# key (the "routing key"), never to a person. PagerDuty turns the event into an
# incident and notifies whoever the service's escalation policy says is on call,
# escalating if nobody acknowledges. Routing keys are write-only credentials:
# they can create incidents but can't read anything back.
#
# https://developer.pagerduty.com/docs/send-alert-event
class PagerDutyService
  # Raised when PagerDuty answered but did not accept the event, so nobody was
  # paged. Distinct from Faraday::Error, which means we never got an answer.
  class EventRejected < StandardError; end

  ENQUEUE_PATH = "/v2/enqueue"

  # PagerDuty truncates longer summaries, and it's the only field that reliably
  # shows up in a push notification.
  MAX_SUMMARY_LENGTH = 1024

  SEVERITIES = ["critical", "error", "warning", "info"].freeze

  def self.conn
    # Short timeouts: callers page synchronously so an admin finds out
    # immediately whether a human was actually reached.
    @conn ||= Faraday.new url: "https://events.pagerduty.com", request: { timeout: 5, open_timeout: 3 } do |f|
      f.request :json
      f.response :raise_error
      f.response :json
    end
  end

  # Routing key for the service that pages the engineering on-call escalation
  # policy when an admin manually asks for help.
  def self.manual_page_routing_key
    Credentials.fetch(:PAGERDUTY, :MANUAL_PAGE_ROUTING_KEY)
  end

  def self.manual_page_enabled?
    manual_page_routing_key.present?
  end

  def self.trigger(routing_key:, summary:, source:, severity: "critical", client_url: nil, component: nil, group: nil, klass: nil, custom_details: {}, links: [])
    raise ArgumentError, "unknown severity: #{severity.inspect}" unless SEVERITIES.include?(severity)

    body = {
      routing_key:,
      event_action: "trigger",
      client: "HCB",
      client_url:,
      payload: {
        summary: summary.truncate(MAX_SUMMARY_LENGTH),
        source:,
        severity:,
        timestamp: Time.current.iso8601,
        component:,
        group:,
        class: klass,
        custom_details:
      }.compact,
      links:
    }.compact

    response = conn.post(ENQUEUE_PATH, body)
    verify_accepted!(response)
    response.body
  rescue => e
    # AppSignal turns the Rails error reporter's `context:` into tags, which
    # can't hold nested hashes, so the body gets dropped. Attach it as custom
    # data (which supports nesting) and keep scalars as filterable tags.
    Appsignal.add_tags(
      pager_duty_source: source,
      response_status: e.try(:response_status)
    )
    Appsignal.add_custom_data(
      pager_duty: {
        summary:,
        source:,
        severity:,
        response_status: e.try(:response_status),
        response_body: e.try(:response_body)
      }
    )
    raise
  end

  # PagerDuty acknowledges an accepted event with 202 and a body of
  # `{"status": "success", "dedup_key": ...}`. Faraday's `raise_error` only
  # covers 4xx and 5xx, so without this check a 200 from an intercepting proxy,
  # a 301 to another host, a 204, or a 202 carrying `{"status": "invalid
  # event"}` would all read as a successful page and nobody would be woken up.
  private_class_method def self.verify_accepted!(response)
    body = response.body

    return if response.status == 202 &&
              body.is_a?(Hash) &&
              body["status"] == "success" &&
              body["dedup_key"].present?

    raise EventRejected, "PagerDuty did not accept the event (HTTP #{response.status}, body: #{body.inspect.truncate(500)})"
  end

end
