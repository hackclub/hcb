# frozen_string_literal: true

# == Schema Information
#
# Table name: contracts
#
#  id                   :bigint           not null, primary key
#  aasm_state           :string           not null
#  contractable_type    :string
#  cosigner_email       :string
#  deleted_at           :datetime
#  external_service     :integer
#  include_videos       :boolean
#  prefills             :jsonb
#  signed_at            :datetime
#  type                 :string           not null
#  void_at              :datetime
#  created_at           :datetime         not null
#  updated_at           :datetime         not null
#  contractable_id      :bigint
#  document_id          :bigint
#  external_id          :string
#  external_template_id :string
#
# Indexes
#
#  index_contracts_on_contractable  (contractable_type,contractable_id)
#  index_contracts_on_document_id   (document_id)
#
# Foreign Keys
#
#  fk_rails_...  (document_id => documents.id)
#
class Contract < ApplicationRecord
  include AASM
  include Hashid::Rails

  acts_as_paranoid
  has_paper_trail

  belongs_to :document, optional: true
  belongs_to :contractable, polymorphic: true

  has_one :organizer_position, required: false
  has_many :parties

  validate :one_non_void_contract

  validates_email_format_of :cosigner_email, allow_nil: true, allow_blank: true
  normalizes :cosigner_email, with: ->(cosigner_email) { cosigner_email.strip.downcase }

  # Always create HCB's party on all contracts
  # Contracts for subevents can be issued by non-admins, so fallback to system user in those cases
  after_create do
    whodunnit = PaperTrail.request.whodunnit
    whodunnit_user = whodunnit.present? ? User.find(whodunnit) : nil

    user = User.system_user
    if whodunnit_user&.admin?
      user = whodunnit_user
    end
    parties.create!(user:, role: :hcb)
  end

  aasm timestamps: true do
    state :pending, initial: true
    state :sent
    state :signed
    state :voided

    event :mark_sent do
      transitions from: :pending, to: :sent
      after do
        if contractable.contract_notify_when_sent
          parties.not_hcb.each(&:notify)
        end
      end
    end

    event :mark_signed do
      transitions from: [:pending, :sent], to: :signed
      after do
        contractable.on_contract_signed(self)
      end
    end

    event :mark_voided do
      transitions from: [:pending, :sent], to: :voided
      after do
        archive_on_docuseal!
        contractable.on_contract_voided(self)
      end
    end
  end

  enum :external_service, {
    docuseal: 0,
    manual: 999 # used to backfill contracts
  }, prefix: :sent_with

  scope :not_voided, -> { where.not(aasm_state: :voided) }

  def docuseal_document
    docuseal_client.get("submissions/#{external_id}").body
  end

  def pending_signee_information
    # This method should be overwritten in subclasses of Contract
    raise NotImplementedError, "The #{self.class.name} model hasn't implemented it's own pending signee information."
  end

  def payload
    # This method should be overwritten in subclasses of Contract
    raise NotImplementedError, "The #{self.class.name} model hasn't implemented it's own contract payload data."
  end

  def required_roles
    # This method should be overwritten in subclasses of Contract
    raise NotImplementedError, "The #{self.class.name} model hasn't implemented it's own required roles"
  end

  def send!
    raise ArgumentError, "can only send contracts when pending" unless pending?

    existing_roles = parties.map(&:role)
    missing_roles = required_roles.select { |role| existing_roles.exclude? role }
    raise ArgumentError, "contract missing required roles: #{missing_roles.join ", "}" unless missing_roles.empty?

    send_using_docuseal! unless sent_with_manual?

    mark_sent!
  end

  def event
    contractable.contract_event if contractable.respond_to?(:contract_event)
  end

  def event_name
    event&.name || prefills["name"]
  end

  def redirect_path
    contractable.contract_redirect_path
  end

  def party(role)
    parties.find_by(role:)
  end

  def on_party_signed(party)
    if parties.all?(&:signed?)
      mark_signed!
    elsif parties.not_hcb.all?(&:signed?)
      party(:hcb).notify
    end

    contractable.on_contract_party_signed(party)
  end

  # Adding this back temporarily while we work on fixing missing parties
  def signee_docuseal_url
    "https://docuseal.co/s/#{contract.docuseal_document["submitters"].select { |s| s["role"] == "Contract Signee" }[0]["slug"]}"
  end

  private

  def docuseal_client
    @docuseal_client || begin
      Faraday.new(url: "https://api.docuseal.co/") do |faraday|
        faraday.response :json
        faraday.response :raise_error
        faraday.adapter Faraday.default_adapter
        faraday.headers["X-Auth-Token"] = Credentials.fetch(:DOCUSEAL)
        faraday.headers["Content-Type"] = "application/json"
      end
    end
  end

  def send_using_docuseal!
    response = docuseal_client.post("/submissions") do |req|
      req.body = payload.to_json
    end

    update(external_service: :docuseal, external_id: response.body.first["submission_id"])

    submitters = docuseal_document["submitters"]

    parties.each do |party|
      slug = submitters.select { |s| s["role"] == party.docuseal_role }&.[](0)&.[]("slug")

      if slug.present?
        party.update!(external_id: slug)
      else
        Rails.error.unexpected("Contract Party (#{party.id}) role and/or slug missing in DocuSeal.")
      end
    end
  end

  def archive_on_docuseal!
    docuseal_client.delete("/submissions/#{external_id}")
  end

  def one_non_void_contract
    if contractable.contracts.not_voided.excluding(self).any?
      self.errors.add(:base, "source already has a contract!")
    end
  end

end
