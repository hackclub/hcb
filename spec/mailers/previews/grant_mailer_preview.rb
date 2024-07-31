# frozen_string_literal: true

class GrantMailerPreview < ActionMailer::Preview
  def invitation
    GrantMailer.with(
      grant: Grant.last
    ).invitation
  end

  def approved
    GrantMailer.with(
      grant: Grant.last
    ).approved
  end

end
