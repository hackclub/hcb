# frozen_string_literal: true

class OperationsMailer < ApplicationMailer
  def g_suite_entering_created_state
    @g_suite = GSuite.find(params[:g_suite_id])

    attrs = {
      to: ::ApplicationMailer::OPERATIONS_EMAIL,
      subject: "[OPS] [ACTION] [Google Workspace] Process #{@g_suite.domain}"
    }

    mail attrs
  end

end
