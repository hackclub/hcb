# frozen_string_literal: true

module CardGrantsHelper
  def grants_sort_direction(column)
    if params[:sort] != column
      return "desc"
    end

    params[:direction] == "desc" ? "asc" : "desc"
  end

  def grants_sort_icon(column)
    if params[:sort] != column
      return "sort-vertical"
    end

    params[:direction] == "asc" ? "up-caret" : "down-caret"
  end

  def build_grants_sort_clause
    sort_column = params[:sort]
    sort_dir = params[:direction] == "asc" ? :asc : :desc
    case sort_column
    when "status"
      { state: sort_dir }
    when "date"
      { created_at: sort_dir }
    when "to"
      { user_id: sort_dir }
    when "for"
      { purpose: sort_dir }
    when "amount"
      { amount_cents: sort_dir }
    when "balance"
      { balance: sort_dir }
    else
      { created_at: :desc }
    end
  end
end
