# frozen_string_literal: true

class AirbrakeSubscriber
  def report(error, handled:, severity:, context:, source: nil)
    airbrake_context = extract_context(context.dup)

    Airbrake.notify(error, { context: airbrake_context, handled:, severity:, source: })
  end

  def extract_context(context)
    controller = context.delete(:controller)

    context.merge!({
                     controller_name: controller&.controller_name,
                     action_name: controller&.action_name,
                     current_user_id: controller&.current_user&.id,
                     current_user_email: controller&.current_user&.email,
                     current_session_id: controller&.session&.id,
                   })
  end

end

Rails.error.subscribe(AirbrakeSubscriber.new)
