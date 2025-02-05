/* eslint-disable no-undef */

// BK is our global namespace for utilities
const BK = {
  blocked: false,
}

window.getCookie = (name) => {
  const nameEQ = name + "=";
  const ca = document.cookie.split(';');
  for (let i = 0; i < ca.length; i++) {
    let c = ca[i];
    while (c.charAt(0) == ' ') c = c.substring(1, c.length);
    if (c.indexOf(nameEQ) == 0) return c.substring(nameEQ.length, c.length);
  }
  return null;
}

window.setCookie = (name, value, days) => {
  let expires = "";
  if (days) {
    const date = new Date();
    date.setTime(date.getTime() + (days * 24 * 60 * 60 * 1000));
    expires = "; expires=" + date.toUTCString();
  }
  document.cookie = name + "=" + (value || "") + expires + "; path=/";
}


// A FOUC is unavoidable, so we set another cookie called `system_preference`. It'll still glitch on first load, but it'll be fixed on the next page load.
window.addEventListener("load", () => {
  setCookie('system_preference', window.matchMedia?.('(prefers-color-scheme: dark)')?.matches ? 'dark' : 'light', 365)
})

// BK.s('some_behavior') is a shortcut for selecting elements by data-behavior
BK.s = (selector, filter = '') =>
  $(`[data-behavior~=${selector}]`).filter(
    filter.length > 0 ? filter : () => true
  )
BK.thereIsNot = (selector, filter) => BK.s(selector, filter).is(':empty')
BK.thereIs = (selector, filter) => !BK.thereIsNot(selector, filter)

BK.deselect = (selector, filter = '[aria-selected=true]') =>
  BK.s(selector, filter).attr('aria-selected', false)
BK.select = (selector, filter) =>
  BK.s(selector, filter).attr('aria-selected', true)

BK.isDark = () => {
  try {
    const cookieSetting = getCookie('theme')
    const isDark = cookieSetting === 'dark' || (cookieSetting === 'system' && window.matchMedia?.('(prefers-color-scheme: dark)')?.matches);
    return (
      isDark || document.getElementsByTagName('html')[0].getAttribute('data-dark') === 'true'
    )
  } catch {
    return false
  }
}

BK.styleDark = _theme => {
  const theme = _theme === "system" ? window.matchMedia?.('(prefers-color-scheme: dark)')?.matches : _theme === "dark";

  const css = document.createElement('style')
  css.type = 'text/css'
  css.appendChild(
    document.createTextNode(
      `* {
         -webkit-transition: none !important;
         -moz-transition: none !important;
         -o-transition: none !important;
         -ms-transition: none !important;
         transition: none !important;
      }`
    )
  )
  document.head.appendChild(css)
  document.getElementsByTagName('html')[0].setAttribute('data-dark', theme)
  document
    .querySelector('meta[name=theme-color]')
    ?.setAttribute('content', theme ? '#17171d' : '#f9fafc')
  // Calling getComputedStyle forces the browser to redraw
  document.head.removeChild(css)
}

BK.toggleDark = () => {
  theme = !BK.isDark()
  window.dispatchEvent(new CustomEvent('theme-toggle', { detail: theme }))
  return BK.setDark(theme)
}

BK.setDark = theme => {
  BK.styleDark(theme)
  setCookie('theme', theme, 365)
  return theme
}

document.addEventListener('turbo:load', () => {
  const dark = BK.isDark()
  document
    .querySelector('meta[name=theme-color]')
    ?.setAttribute('content', dark ? '#17171d' : '#f9fafc')
})

// Listen for Browser dark mode preference changes (`prefers-color-scheme`)
if (window.matchMedia) {
  window
    .matchMedia('(prefers-color-scheme: dark)')
    .addEventListener('change', () => {
      // This will only be called on changes (not during initial page load)
      BK.setDark(getCookie("theme"))
    })
}

// Attempt to load Fullstory
$(document).ready(() => {
  setTimeout(() => {
    if (typeof FS === 'undefined') {
      BK.blocked = true
    } else {
      fetch('https://rs.fullstory.com/rec/page', { method: 'POST' })
        .then(res => {
          if (!res.ok) {
            BK.blocked = true
          }
        })
        .catch(() => {
          BK.blocked = true
        })
    }
  }, 3000)
})

BK.money = amount => {
  if (typeof amount !== 'number') return '–'
  const localAmount = Math.abs(Math.round(amount) / 100).toLocaleString()
  const sign = Math.sign(amount) === -1 ? '-' : ''
  return `${sign}$${localAmount}`
}
