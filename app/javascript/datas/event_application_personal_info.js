export default ({ minor, country, country_label, disallowed_countries }) => ({
  minor,
  country,
  country_label,
  disallowed_countries,

  get country_disallowed() {
    return this.disallowed_countries.includes(this.country)
  },

  // Keeps the country, its display name (needed for the warning copy) and the
  // field's validity in step. A directive can only hold one expression under the
  // CSP build, so all three happen here.
  sync_country(select) {
    this.country = select.value
    this.country_label = select.selectedOptions[0]
      ? select.selectedOptions[0].label
      : ''
    select.setCustomValidity(
      this.country_disallowed ? 'HCB is not supported in this country' : ''
    )
  },
})
