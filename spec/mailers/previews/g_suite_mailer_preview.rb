# frozen_string_literal: true

class GSuiteMailerPreview < ActionMailer::Preview
  def notify_of_configuring
    g_suite = GSuite.configuring.last
    g_suite ||= GSuite.last
    GSuiteMailer.with(g_suite_id: g_suite.id).notify_of_configuring
  end

  def notify_of_verified
    g_suite = GSuite.verified.last
    g_suite ||= GSuite.last
    GSuiteMailer.with(g_suite_id: g_suite.id).notify_of_verified
  end

  def notify_operations_of_entering_created_state
    g_suite = GSuite.last
    GSuiteMailer.with(g_suite_id: g_suite.id).notify_operations_of_entering_created_state.deliver_now
  end

end
