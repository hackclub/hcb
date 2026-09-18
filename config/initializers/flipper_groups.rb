# frozen_string_literal: true

# Flipper groups for enabling features across sets of actors. Membership lives in
# FlipperGroups; here we only wire each group name to a predicate.
#
# Group blocks receive the actor wrapped in Flipper::Types::Actor, whose is_a? is
# not delegated to the wrapped object, so we unwrap with `actor.actor` and let
# FlipperGroups guard the type. Groups are only evaluated when a check passes an
# actor; user groups match User actors and hq_descendant_organizations / organization_plan_ matches
# Event actors.
Flipper.register(:hcb_team)                    { |actor, _context| FlipperGroups.hcb_team?(actor.actor) }
Flipper.register(:hcb_engineers)               { |actor, _context| FlipperGroups.hcb_engineer?(actor.actor) }
Flipper.register(:hackclub_emails)             { |actor, _context| FlipperGroups.hackclub_email?(actor.actor) }
Flipper.register(:admins_and_auditors)         { |actor, _context| FlipperGroups.admin_or_auditor?(actor.actor) }
Flipper.register(:hq_descendant_users)         { |actor, _context| FlipperGroups.hq_descendant_user?(actor.actor) }
Flipper.register(:hq_descendant_organizations) { |actor, _context| FlipperGroups.hq_descendant_organization?(actor.actor) }

# Event::Plan.available_plans Event and the Plan subclasses to be loaded first
Rails.application.config.to_prepare do
  Rails.autoloaders.main.eager_load_dir(Rails.root.join("app/models/event/plan").to_s)

  Event::Plan.available_plans.each do |plan|
    Flipper.register("organization_plan_#{plan.name.demodulize.underscore}".to_sym) do |actor, _context|
      FlipperGroups.event_in_plan?(actor.actor, plan)
    end
  end
end
