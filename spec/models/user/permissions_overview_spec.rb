# frozen_string_literal: true

require "rails_helper"

RSpec.describe User::PermissionsOverview do
  describe "#event_graph" do
    specify "users are managers for descendants but not ancestors" do
      user = create(:user)
      create_nested_events(user:, roles: [nil, "manager", nil])

      instance = described_class.new(user: user)

      expect(snapshot(instance.event_graph).string).to eq(<<~SNAPSHOT)
        > name="Level 1", role=nil
          > name="Level 2", role="manager"
            > name="Level 3", role="manager"
      SNAPSHOT

      check_against_original_code(user, instance.event_graph)
    end

    specify "manager roles take precedence over lesser roles" do
      user = create(:user)
      create_nested_events(user:, roles: [nil, "manager", "reader"])

      instance = described_class.new(user: user)

      expect(snapshot(instance.event_graph).string).to eq(<<~SNAPSHOT)
        > name="Level 1", role=nil
          > name="Level 2", role="manager"
            > name="Level 3", role="manager"
      SNAPSHOT

      check_against_original_code(user, instance.event_graph)
    end

    specify "member roles only apply to one level and become reader for descendants" do
      user = create(:user)
      create_nested_events(user:, roles: [nil, "member", nil])

      instance = described_class.new(user: user)

      expect(snapshot(instance.event_graph).string).to eq(<<~SNAPSHOT)
        > name="Level 1", role=nil
          > name="Level 2", role="member"
            > name="Level 3", role="reader"
      SNAPSHOT

      check_against_original_code(user, instance.event_graph)
    end

    specify "users are reader for descendants but not ancestors" do
      user = create(:user)

      create_nested_events(user:, roles: [nil, "reader", nil])

      instance = described_class.new(user: user)

      expect(snapshot(instance.event_graph).string).to eq(<<~SNAPSHOT)
        > name="Level 1", role=nil
          > name="Level 2", role="reader"
            > name="Level 3", role="reader"
      SNAPSHOT

      check_against_original_code(user, instance.event_graph)
    end

    it "correctly handles multiple trees" do
      user = create(:user)

      create_nested_events(user:, roles: [nil, "member", nil], name_prefix: "Tree 1 Level")
      create_nested_events(user:, roles: [nil, "manager", nil], name_prefix: "Tree 2 Level")

      instance = described_class.new(user: user)

      expect(snapshot(instance.event_graph).string).to eq(<<~SNAPSHOT)
        > name="Tree 1 Level 1", role=nil
          > name="Tree 1 Level 2", role="member"
            > name="Tree 1 Level 3", role="reader"
        > name="Tree 2 Level 1", role=nil
          > name="Tree 2 Level 2", role="manager"
            > name="Tree 2 Level 3", role="manager"
      SNAPSHOT

      check_against_original_code(user, instance.event_graph)
    end

    def create_nested_events(user:, roles:, name_prefix: "Level")
      parent = nil

      roles.each_with_index do |role, index|
        event = create(:event, name: "#{name_prefix} #{index + 1}", parent:, plan: Event::Plan::Standard.new)

        unless role.nil?
          create(:organizer_position, event:, user:, role:)
        end

        parent = event
      end
    end

    def snapshot(nodes, out: StringIO.new, indent: 0)
      nodes.each do |node|
        out.puts "#{"  " * indent}> name=#{node.event.name.inspect}, role=#{node.role.inspect}"

        snapshot(node.child_nodes, out:, indent: indent + 1)
      end

      out
    end

    def check_against_original_code(user, nodes)
      nodes.each do |node|
        if node.role.nil?
          expect(OrganizerPosition.role_at_least?(user, node.event, "reader")).to(
            eq(false),
            "user should not have \"reader\" role on #{node.event.name.inspect}"
          )
        else
          expect(OrganizerPosition.role_at_least?(user, node.event, node.role)).to(
            eq(true),
            "user should have at least #{node.role.inspect} for event #{node.event.name.inspect}"
          )
        end

        check_against_original_code(user, node.child_nodes)
      end
    end
  end
end
