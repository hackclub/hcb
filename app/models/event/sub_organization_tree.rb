# frozen_string_literal: true

class Event
  # The part of an organization's tree a viewer may see, held as id => parent_id
  # so it can be walked without a query per level.
  class SubOrganizationTree
    # Reading the ids back through ActiveRecord drops soft-deleted events, and
    # with them anything nested underneath, which the table cannot expand into
    # either.
    def initialize(descendant_ids:)
      @parents = Event.where(id: descendant_ids).pluck(:id, :parent_id).to_h
    end

    def ids
      @parents.keys
    end

    # The ancestors of `id` within the tree, nearest first. The organization the
    # tree hangs from has no entry, so the walk stops short of it.
    def ancestor_ids(id)
      ancestors = []
      parent_id = @parents[id]

      while @parents.key?(parent_id)
        ancestors << parent_id
        parent_id = @parents[parent_id]
      end

      ancestors
    end

    # `root_ids` together with everything beneath them.
    def subtree_ids(root_ids)
      roots = root_ids.to_set

      ids.select { |id| roots.include?(id) || ancestor_ids(id).any? { |ancestor| roots.include?(ancestor) } }
    end

    # For each of `root_ids`, the ids beneath it, the root itself excluded. A
    # root with nothing beneath it gets no entry, so a table can show a dash
    # rather than a zero.
    def descendant_ids_by_root(root_ids)
      roots = root_ids.to_set

      ids.each_with_object({}) do |id, groups|
        ancestor_ids(id).each do |ancestor|
          (groups[ancestor] ||= []) << id if roots.include?(ancestor)
        end
      end
    end

  end

end
