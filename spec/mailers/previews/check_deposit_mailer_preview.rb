# frozen_string_literal: true

class CheckDepositMailerPreview < ActionMailer::Preview
  def rejected
    CheckDepositMailer.with(
      check_deposit: CheckDeposit.last
    ).rejected
  end

  def approved
    CheckDepositMailer.with(
      check_deposit: CheckDeposit.last
    ).deposited
  end

end
