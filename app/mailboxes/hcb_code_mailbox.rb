# frozen_string_literal: true

class HcbCodeMailbox < ApplicationMailbox
  # mail --> Mail object, this actual email
  # inbound_email => ActionMailbox::InboundEmail record --> the active storage record

  include Pundit::Authorization
  include HasAttachments

  before_processing :set_commands
  before_processing :set_attachments
  before_processing :set_hcb_code
  before_processing :set_user

  def process
    return bounce_missing_attachments unless @attachments || @commands.any?
    return bounce_missing_hcb unless @hcb_code
    return bounce_missing_user unless @user
    return unless ensure_permissions?

    if @attachments&.any? && (@commands.empty? || mail.attachments.any?)
      result = ::ReceiptService::Create.new(
        receiptable: @hcb_code,
        uploader: @user,
        attachments: @attachments,
        upload_method: "email_hcb_code"
      ).run!
    end

    @commands.each do |command|
      process_command(command)
    end

    return bounce_error if result&.empty? && @commands.none?

    HcbCodeMailer.with(
      mail: inbound_email,
      reply_to: @hcb_code.receipt_upload_email,
      renamed_to: @renamed_to,
      tagged_with: @tagged_with,
      reversed_pairing: @reversed_pairing,
      receipts_count: result&.size || 0
    ).bounce_success.deliver_now
  end

  private

  def set_commands
    content = text || html && Loofah.html5_fragment(html).to_text || body
    @commands = content&.lines&.select { |line| line.strip.start_with?("@") }&.map { |cmd|
      {
        "command"  => cmd.strip.split(" ")[0],
        "argument" => cmd.sub(cmd.strip.split(" ")[0], "").strip
      }
    } || []
    @tagged_with = []
  end

  def process_command(command)
    case command["command"]
    when "@rename"
      return unless command["argument"]

      @hcb_code.canonical_transactions.each { |ct| ct.update!(custom_memo: command["argument"]) }
      @hcb_code.canonical_pending_transactions.each { |cpt| cpt.update!(custom_memo: command["argument"]) }
      @renamed_to = command["argument"]
    when "@tag"
      return unless command["argument"] && Flipper.enabled?(:transaction_tags_2022_07_29, @hcb_code.event)

      event = @hcb_code.event
      tag = event.tags.search_label(command["argument"]).first
      return unless tag

      suppress(ActiveRecord::RecordNotUnique) do
        @hcb_code.tags << tag
      end
      @tagged_with << tag.label
    when "@reverse"
      @reversed_pairing = SuggestedPairing.find_by(hcb_code_id: @hcb_code.id, aasm_state: :accepted)
      return unless @reversed_pairing

      @reversed_pairing.mark_reveresed!
    end
  end

  def set_hcb_code
    email_comment = mail.to.first.match(/\+.*@/i)[0]
    hcb_code_hashid = email_comment.match(/hcb-(.*)@/i).captures.first
    @hcb_code = HcbCode.find_by_hashid hcb_code_hashid
  end

  def set_user
    @user = User.find_by(email: mail.from[0])
  end

  def bounce_missing_user
    bounce_with HcbCodeMailer.with(mail: inbound_email).bounce_missing_user
  end

  def bounce_missing_hcb
    bounce_with HcbCodeMailer.with(mail: inbound_email).bounce_missing_hcb
  end

  def bounce_error
    bounce_with HcbCodeMailer.with(
      mail: inbound_email,
      reply_to: @hcb_code.receipt_upload_email
    ).bounce_error
  end

  def ensure_permissions?
    return true if @hcb_code.nil?

    authorize @hcb_code, :upload?, policy_class: ReceiptablePolicy

  rescue Pundit::NotAuthorizedError
    # We return with the email equivalent of 404 if you don't have permission
    bounce_with HcbCodeMailer.with(mail: inbound_email).bounce_missing_hcb
    false
  end

  def pundit_user
    @user
  end

end
