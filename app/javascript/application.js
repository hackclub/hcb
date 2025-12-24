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

import { Turbo } from '@hotwired/turbo-rails'
window.Turbo = Turbo

import persist from '@alpinejs/persist'
import Alpine from 'alpinejs'
import ach_form from './datas/ach_form'
import wire_form from './datas/wire_form'
import check_form from './datas/check_form'

window.Alpine = Alpine
Alpine.plugin(persist)
Alpine.data('ach', ach_form)
Alpine.data('wire', wire_form)
Alpine.data('check', check_form)

Alpine.start()

import LocalTime from 'local-time'
LocalTime.start()

import '@github/text-expander-element'
import '@oddbird/popover-polyfill'
import 'emoji-picker-element'
