import $ from 'jquery'
import ReactRailsUJS from 'react_ujs'

// Initialize Intl polyfill globally before any components load
// This prevents "IntlPolyfill is not defined" errors
import 'intl'
import 'intl/locale-data/jsonp/en-US'

// Explicitly import home components to ensure they're in the bundle
// This prevents race conditions when loading via turbo frames
import './components/home'

// Support component names relative to this directory:
var componentRequireContext = require.context('./components', true)
ReactRailsUJS.useContext(componentRequireContext)

ReactRailsUJS.handleEvent('turbo:load', ReactRailsUJS.handleMount)
ReactRailsUJS.handleEvent('turbo:before-render', ReactRailsUJS.handleUnmount)

ReactRailsUJS.handleEvent('turbo:frame-load', ReactRailsUJS.handleMount)
ReactRailsUJS.handleEvent('turbo:frame-render', ReactRailsUJS.handleUnmount)

// Remove modals triggered by <turbo-frames> when the frame is unloaded.
// Bad stuff happens if you don't do this. Trust me. ~ @cjdenio
document.addEventListener('turbo:frame-render', () => {
  // prettier-ignore
  $('.jquery-modal [data-behavior~=modal].turbo-frame-modal:not(.modal--popover)').remove()
})

document.addEventListener('turbo:before-cache', () => {
  const currentModal = $.modal.getCurrent()

  if (currentModal) {
    currentModal.options.doFade = false
    currentModal.close()
  }

  $('.field_with_errors').removeClass('field_with_errors')
})

import './controllers'
import './confirm'

import { Turbo } from '@hotwired/turbo-rails'
window.Turbo = Turbo

import persist from '@alpinejs/persist'
// The CSP build swaps Alpine's `new Function(...)` compiler for a small parser
// and interpreter, so no directive needs `script-src 'unsafe-eval'`. It only
// understands a subset of JS: a single expression per directive, no arrow
// functions, no template literals, no optional chaining, and no globals.
import Alpine from '@alpinejs/csp'
import ach_form from './datas/ach_form'
import wire_form from './datas/wire_form'
import check_form from './datas/check_form'
import wise_form from './datas/wise_form'
import application_project_info_form from './datas/application_project_info_form'
import application_edit_project_info from './datas/application_edit_project_info'
import application_affiliation_form from './datas/application_affiliation_form'
import admin_tools_pinned_cards from './datas/admin_tools_pinned_cards'
import allowance_form from './datas/allowance_form'
import donation_form from './datas/donation_form'
import event_application_personal_info from './datas/event_application_personal_info'
import payout_ach_fields from './datas/payout_ach_fields'
import scoped_tag_picker from './datas/scoped_tag_picker'
import team_email_check from './datas/team_email_check'
import is_minor from './magics/is_minor'

window.Alpine = Alpine
Alpine.plugin(persist)
Alpine.data('ach', ach_form)
Alpine.data('wire', wire_form)
Alpine.data('check', check_form)
Alpine.data('wise_form', wise_form)
Alpine.data('application_project_info', application_project_info_form)
Alpine.data('application_edit_project_info', application_edit_project_info)
Alpine.data('application_affiliation_form', application_affiliation_form)
Alpine.data('admin_tools_pinned_cards', admin_tools_pinned_cards)
Alpine.data('allowance_form', allowance_form)
Alpine.data('donation_form', donation_form)
Alpine.data('event_application_personal_info', event_application_personal_info)
Alpine.data('payout_ach_fields', payout_ach_fields)
Alpine.data('scoped_tag_picker', scoped_tag_picker)
Alpine.data('team_email_check', team_email_check)
Alpine.magic('isMinor', is_minor)

Alpine.start()

import LocalTime from 'local-time'
LocalTime.start()

import '@github/text-expander-element'
import '@oddbird/popover-polyfill'
import 'emoji-picker-element'
