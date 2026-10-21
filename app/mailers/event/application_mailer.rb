# frozen_string_literal: true

class Event
  class ApplicationMailer < ::ApplicationMailer
    before_action { @application = params[:application] }

    def confirmation
      mail to: @application.user.email_address_with_name, subject: "Thank you for applying to HCB!"
    end

    def under_review
      mail to: @application.user.email_address_with_name, subject: "Your HCB application is under review"
    end

    def incomplete
      tips = [
        "Each HCB organization gets a free online donation page that can be used to raise funds. All donors need is a credit card, and you can customize the page however you'd like!",
        "HCB allows you to get reimbursed for out-of-pocket expenses towards your organization's mission.",
        "You can issue physical and virtual debit cards to spend money for your organization directly. Digital wallets like Apple Pay and Google Pay are supported too!",
        "With our mobile app, you can track fundraising and spending on the go. Issue cards, collect donations, and upload receipts from anywhere!"
      ]
      @tip = tips[(params[:tip_number].to_i - 1) % tips.length]
      mail to: @application.user.email_address_with_name, subject: "[Action Needed] Complete your HCB application!"
    end

    def rejected
      @rejection_message = params[:rejection_message]
      mail to: @application.user.email_address_with_name, subject: "Update on your HCB application"
    end

    def activated
      mail to: @application.user.email_address_with_name, subject: "[#{@application.name}] Welcome to HCB!"
    end

    def approved
      mail to: @application.user.email_address_with_name, subject: "[Action Needed] #{@application.name} has been approved"
    end

  end

end
