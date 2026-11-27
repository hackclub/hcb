# frozen_string_literal: true

# == Schema Information
#
# Table name: marketing_inquiries
#
#  id         :bigint           not null, primary key
#  audience   :string
#  email      :string           not null
#  message    :text
#  name       :string
#  page       :string           not null
#  ref        :string
#  created_at :datetime         not null
#  updated_at :datetime         not null
#
# Indexes
#
#  index_marketing_inquiries_on_page_and_created_at  (page,created_at)
#
# Contact details submitted on public marketing pages. Readable by admins via the
# console and Blazer; delete on request.
class MarketingInquiry < ApplicationRecord
  PAGES = %w[ai_safety].freeze

  # The one source for the AI safety form's "I am" options and their labels.
  AUDIENCES = {
    "team"      => "A funded team or researcher",
    "funder"    => "A funder or grantmaker",
    "program"   => "Running a fellowship or program",
    "exploring" => "Closing a grant or exploring"
  }.freeze

  REF_FORMAT = /\A[a-z0-9_-]{1,64}\z/

  # Text that could carry a link or phone number. The confirmation email leaves
  # anything matching this out, so the form can't be used to mail spam to a stranger.
  # Errs toward leaving text out.
  LINKISH = /(https?:|www\.|@|\b[a-z0-9-]+\s*(?:\.|\[\.\]|\(\.\)|\[dot\]|\(dot\))\s*[a-z]{2,}\b|\d{3}[\s.-]?\d{3}[\s.-]?\d{4})/i

  validates :page, inclusion: { in: PAGES }
  validates :audience, inclusion: { in: AUDIENCES.keys }, allow_nil: true
  validates :email, presence: true, length: { maximum: 254 }, format: { with: URI::MailTo::EMAIL_REGEXP }
  validates :name, length: { maximum: 200 }
  validates :message, length: { maximum: 5_000 }
  validates :ref, format: { with: REF_FORMAT }, allow_nil: true

end
