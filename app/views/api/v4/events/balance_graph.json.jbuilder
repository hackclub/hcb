# frozen_string_literal: true

json.balance_by_date @balance_graph[:data].transform_keys(&:to_s)
json.balance_trend @balance_graph[:trend]
