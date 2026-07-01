/*
  StrictHwComboboxController — a drop-in subclass of the hotwire_combobox
  controller that fixes a money-movement footgun in async (server-search)
  comboboxes, without adding any UI friction.

  THE PROBLEM (async combobox only)

  As you type, the gem commits the FIRST server result to the hidden form field
  even when you never deliberately chose it:

    1. While typing: `_selectOnQuery` reaches
       `else if (this._isOpen && this._visibleOptionElements[0])` and calls
       `_select(firstOption, _softAutocomplete)`, writing the hidden value.
       `_softAutocomplete` only rewrites the VISIBLE input when the option label
       starts with what you typed, so a fuzzy server match (type "bank", server
       matches "HCB Operations" on some other field) commits silently — the
       visible text never changes.
    2. On close / Enter / blur: `_lockInSelection` uses
       `_ensurableOption = _selectedOptionElement || _visibleOptionElements[0]`,
       so even with (1) suppressed, blurring would still lock in the first result.

  On the transfer form this means a user can send from/to the wrong (but
  authorized) organization without ever picking it. See
  app/controllers/disbursements_controller.rb and
  app/views/disbursements/_select_organization.html.erb.

  THE FIX

  Both paths already have a reliable signal for "did the user mean this option":
  the gem's own case-insensitive prefix test, `startsWith(optionDisplay, typed)`.

    - Type a prefix ("hack club h" -> "Hack Club HQ") — the option starts with
      your query, so committing + inline-autocompleting is the normal, wanted
      typeahead. We leave it untouched.
    - Type a fuzzy substring ("bank" -> "HCB Operations") — the option does NOT
      start with your query, so we keep the form value EMPTY until you click a
      row, arrow to one, or type a real prefix. A blank submit is then caught by
      the disbursement-form#onSubmit hidden-value guard (while the picker is
      open, before the gem clears the typed text), by native `required` (after
      close clears that text), and authoritatively by the server.

  Clicking and arrow-navigating are unaffected (they go through
  `selectOnClick` / `_selectIndex`, which force an explicit selection).

  SCOPE / SAFETY

  Behavior only changes when `data-hw-combobox-strict-value="true"` is present
  (set by the transfer org pickers). Every other combobox — admin filters,
  `name_when_new` pickers — is byte-for-byte unchanged. Strict mode is only used
  where new options are disallowed, so the override can ignore the new-option
  branch of `_selectOnQuery`.

  This wraps `super`; it does not copy gem method bodies. It couples only to a
  few internal names (`_selectOnQuery`, `_ensurableOption`, `_isAsync`,
  `_isOpen`, `_typedQuery`, `_visibleOptionElements`, `_selectedOptionElement`,
  `_resetOptionsAndNotify`, `_markInvalid`, `autocompletableAttributeValue`, the
  `hw:lockInSelection` inputType). The gem version is pinned exactly in
  package.json; `connect()` asserts these names still exist and throws loudly if
  an upgrade removes them, rather than silently reverting to the buggy behavior.
*/

import HwComboboxController from '@josefarias/hotwire_combobox'

export default class StrictHwComboboxController extends HwComboboxController {
  // Stimulus aggregates static `values` up the prototype chain, so this ADDS to
  // the gem's values rather than replacing them. Reads
  // `data-hw-combobox-strict-value`.
  static values = { strict: Boolean }

  // Fail LOUD, not silent. Every override below couples to gem-internal method
  // and getter names. If a future gem upgrade renames any of them, the couplings
  // would otherwise degrade silently *toward* the unsafe auto-commit this fix
  // exists to prevent (e.g. a renamed `_typedQuery` reads `undefined` -> `''` ->
  // `startsWith('')` is always true -> suppression never fires). We assert the
  // contract at connect time so the failure surfaces via the app's Stimulus
  // error handler (AppSignal, see index.js) instead of quietly re-arming the
  // footgun. Only runs for strict pickers; the gem is pinned exactly in
  // package.json, so this can only trip on a deliberate upgrade.
  //
  // NOTE: this asserts the coupled names still EXIST, not that their behavior is
  // unchanged. A gem upgrade that keeps a name but alters its semantics (e.g.
  // `_typedQuery` starts returning the autocompleted rather than typed text) can
  // still regress silently. Re-verify the actual suppression behavior on upgrade,
  // not just a green boot.
  connect() {
    super.connect()
    if (this.strictValue) this.#assertGemContract()
  }

  get _strict() {
    return this.strictValue
  }

  // Case-insensitive: does this option's display start with what the user typed?
  // `_typedQuery` is the unselected (actually-typed) portion of the input, so an
  // in-progress inline autocomplete doesn't fool it.
  _optionPrefixMatchesTypedQuery(option) {
    const display = (
      option.getAttribute(this.autocompletableAttributeValue) || ''
    ).toLowerCase()
    return display.startsWith((this._typedQuery || '').toLowerCase())
  }

  // Path 1 — while typing. Suppress the silent commit of a fuzzy first result;
  // let everything else (deletes, new options, prefix matches, the closed-dialog
  // case, lock-in) fall through to the gem unchanged.
  _selectOnQuery(inputType) {
    if (this._shouldSuppressSilentAutoCommit(inputType)) {
      // Mirror the gem's own no-selectable-option branch (selection.js): clear
      // the value AND mark the field invalid, so aria-invalid/aria-errormessage
      // reflect the empty value while the fuzzy result is showing.
      this._resetOptionsAndNotify() // keep the form value empty until a real pick
      this._markInvalid()
      return
    }

    super._selectOnQuery(inputType)
  }

  _shouldSuppressSilentAutoCommit(inputType) {
    if (!this._strict || !this._isAsync || !this._isOpen) return false
    if (inputType === 'hw:lockInSelection') return false
    if ((inputType || '').startsWith('delete')) return false // let the gem deselect
    if (this._selectedOptionElement) return false // an explicit pick already stands

    const option = this._visibleOptionElements[0]
    return !!option && !this._optionPrefixMatchesTypedQuery(option)
  }

  // Path 2 — on close / Enter / blur. Only lock in an option the user explicitly
  // selected (clicked/arrowed) or a genuine prefix match; never an arbitrary
  // fuzzy first result. Returning null leaves the value blank, and the gem's
  // `_clearInvalidQuery` then clears the leftover typed text.
  get _ensurableOption() {
    const option = super._ensurableOption
    if (!option || !this._strict || !this._isAsync) return option
    if (this._selectedOptionElement) return option

    return this._optionPrefixMatchesTypedQuery(option) ? option : null
  }

  // Throws if any gem-internal name the overrides depend on has gone missing.
  // The overridden names (_selectOnQuery, _ensurableOption) are checked on the
  // gem's prototype chain specifically — our own overrides must not mask a
  // removal, since `super` would then be undefined.
  #assertGemContract() {
    const gemProto = Object.getPrototypeOf(Object.getPrototypeOf(this))
    const required = [
      '_selectOnQuery',
      '_ensurableOption',
      '_resetOptionsAndNotify',
      '_markInvalid',
      '_isAsync',
      '_isOpen',
      '_typedQuery',
      '_visibleOptionElements',
      '_selectedOptionElement',
    ]

    const missing = required.filter(
      name => !this.#protoChainHas(gemProto, name)
    )

    if (
      typeof this.autocompletableAttributeValue !== 'string' ||
      this.autocompletableAttributeValue === ''
    ) {
      missing.push('autocompletableAttributeValue')
    }

    if (missing.length > 0) {
      throw new Error(
        `StrictHwCombobox: hotwire_combobox contract broken (missing: ${missing.join(', ')}). ` +
          'The strict transfer-org guard is inert, so a fuzzy search result could silently ' +
          'commit the wrong organization. Re-verify strict_hw_combobox.js against the upgraded gem.'
      )
    }

    // Strict mode assumes new options are disallowed (see the suppress branch,
    // which treats a non-prefix-matching first result as "no valid selection").
    // On a picker that allows new options, that would silently swallow a
    // legitimately typed new value. We don't use the two together today; fail
    // loud if someone ever wires them up rather than shipping a broken picker.
    if (this.nameWhenNewValue) {
      throw new Error(
        'StrictHwCombobox: strict mode is incompatible with name_when_new — a typed ' +
          'new option would be suppressed. Remove data-hw-combobox-strict-value or name_when_new.'
      )
    }
  }

  #protoChainHas(startProto, name) {
    for (
      let proto = startProto;
      proto && proto !== Object.prototype;
      proto = Object.getPrototypeOf(proto)
    ) {
      if (Object.getOwnPropertyDescriptor(proto, name)) return true
    }
    return false
  }
}
