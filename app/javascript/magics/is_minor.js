// Eighteen years, in milliseconds — the same constant the birthday handlers
// used inline before they moved here.
const EIGHTEEN_YEARS = 568_025_136_000

// `$isMinor($el)` reads a Rails `date_select` (three <select>s in a wrapper) and
// reports whether the chosen date is less than eighteen years ago. It is a magic
// rather than a component method because two different application forms need it
// inside `x-data` scopes that otherwise have nothing in common.
export default () => dateSelect => {
  const parts = [...dateSelect.children].map(
    select => select.selectedOptions[0].label
  )

  return Date.now() - new Date(parts.join(' ')) < EIGHTEEN_YEARS
}
