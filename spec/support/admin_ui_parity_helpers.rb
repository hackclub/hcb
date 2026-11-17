# frozen_string_literal: true

# Shared by the admin UI parity specs (spec/misc/admin_*_parity_spec.rb).
#
# The admin UI rewrite (AdminUI3) was meant to be visual only. Those specs pin
# the behaviour the old admin had: which endpoints each screen submits to, with
# which param names, which filters stick, which destructive actions confirm,
# and which pages the nav reaches. The expected values were taken by rendering
# every admin page on `main` before the rewrite and diffing against the new UI.
#
# If one of them fails because you meant to change a form, update the
# expectation — but make sure the controller still reads the new params.
module AdminUiParityHelpers
  def page
    Nokogiri::HTML(response.body)
  end

  # Every form on the page as `[method, action, [field names]]`, ignoring
  # Rails plumbing (CSRF token, `_method`, submit button names) and the
  # layout's own forms (logout, "pretend I'm not an admin").
  def form_contracts
    page.css("form").filter_map do |form|
      action = form["action"].to_s
      next if action.start_with?("/users/")

      method = (form.at_css("input[name=_method]")&.[]("value") || form["method"] || "get").downcase
      names = form.css("input, select, textarea").filter_map do |input|
        name = input["name"]
        next if name.blank? || name.in?(%w[authenticity_token _method commit button])
        next if input["disabled"] && input["type"] == "hidden"

        name
      end
      [method, action, names.uniq.sort]
    end
  end

  def form_fields(method, action)
    matches = form_contracts.select { |m, a, _| m == method && a == action }
    expect(matches).not_to be_empty, "expected a #{method.upcase} form to #{action}, got: #{form_contracts.map { |m, a, _| "#{m.upcase} #{a}" }.inspect}"
    matches.flat_map(&:last).uniq.sort
  end

  def filter_form(action)
    page.css("form").find { |f| f["action"] == action && f["method"].to_s.downcase == "get" } ||
      raise("no GET filter form for #{action}")
  end
end
