# frozen_string_literal: true

class StripeCard
  # This is basically describing the flows. The reason I am doing it like this is so I can extend it and don't have to remake the turbo for damaged/lost/stolen/expired cards.
  class ReplacementFlow
    FLOWS = {
      "damaged" => {
        title: "Replace damaged card",
        reasons: %w[damaged],
        steps: %w[reason new_card confirm shipping],
        policy: :replace?,
      },
      "losten"  => {
        title: "Replace lost or stolen card",
        reasons: %w[lost stolen],
        steps: %w[reason new_card confirm shipping],
        policy: :replace_lost_or_stolen?,
      },
      "expired" => {
        title: "Replace expiring card",
        reasons: %w[expired],
        steps: %w[new_card confirm shipping],
        policy: :replace_expired?,
      },
    }.freeze

    CONFIRMATION_STEPS = %w[reason confirm].freeze

    attr_reader :stripe_card, :key, :reason, :dispute

    PHYSICAL_ONLY_REASONS = %w[lost damaged].freeze

    def self.supported?(key)
      FLOWS.key?(key.to_s)
    end

    def self.policy_query_for(reason)
      FLOWS.values.find { |flow| flow[:reasons].include?(reason.to_s) }&.fetch(:policy)
    end

    def initialize(stripe_card:, flow:, reason: nil, dispute: nil)
      raise ArgumentError, "#{flow.inspect} is not a supported replacement flow" unless self.class.supported?(flow)
      raise ArgumentError, "can only dispute this card's transactions" if dispute && dispute.stripe_card != stripe_card

      @stripe_card = stripe_card
      @key = flow.to_s
      @dispute = dispute
      @reason = reasons.include?(reason.to_s) ? reason.to_s : (reasons.first if reasons.one?)
    end

    def title
      return "Dispute this transaction" if dispute
      return "Replace expired card" if expired? && stripe_card.expired?

      FLOWS.fetch(key)[:title]
    end

    def policy_query
      FLOWS.fetch(key)[:policy]
    end

    def available?
      reasons.any?
    end

    def frame_id
      [ActionView::RecordIdentifier.dom_id(stripe_card, "replacement_#{key}"), dispute && "dispute_#{dispute.hashid}"].compact.join("_")
    end

    def dom_id(suffix)
      "#{frame_id}_#{suffix}"
    end

    def reasons
      reasons = FLOWS.fetch(key)[:reasons]
      reasons -= PHYSICAL_ONLY_REASONS if stripe_card.virtual?
      reasons
    end

    def chooses_reason?
      reasons.many?
    end

    def steps
      steps = FLOWS.fetch(key)[:steps]
      steps -= %w[shipping] if stripe_card.virtual?
      steps = ["compromised", *steps] if dispute
      steps
    end

    def find_step(step)
      step = step.to_s
      return steps.first unless steps.include?(step)

      reason_index = steps.index("reason")
      return "reason" if reason.nil? && reason_index && steps.index(step) > reason_index

      step
    end

    def step_number(step)
      steps.index(step) + 1
    end

    def next_step(step)
      steps[steps.index(step) + 1]
    end

    def previous_step(step)
      index = steps.index(step)
      index.positive? ? steps[index - 1] : nil
    end

    def last_step?(step)
      step == steps.last
    end

    def requires_confirmation?(step)
      # Nothing to confirm about canceling a card that's already canceled
      return false if step == "confirm" && stripe_card.canceled?

      CONFIRMATION_STEPS.include?(step)
    end

    def params(step: nil)
      { flow: key, reason:, dispute: dispute&.hashid, step: }.compact
    end

    def damaged?
      reason == "damaged"
    end

    def lost?
      reason == "lost"
    end

    def stolen?
      reason == "stolen"
    end

    def expired?
      reason == "expired"
    end

    def keeps_card_number?
      %w[expired damaged].include?(reason)
    end

  end

end
