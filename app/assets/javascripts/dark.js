// (msw) This should be loaded syncronously (don't defer or async) before the page
// loads in. It prevents users in dark mode from getting flashed by a bright
// light when the page loads in.

try {
  ; (function () {
    if (
      document.querySelector('html').getAttribute('data-ignore-theme') != null
    ) {
      // Ignore the user's theme preference
      return
    }

    const darkModeConfig = localStorage.getItem('dark')
    let darkMode = darkModeConfig == 'true'

    if (darkModeConfig === null) {
      // HCB has not stored a dark mode preference. Fallback to the browser's
      // `prefers-color-scheme` preference.
      if (
        window.matchMedia &&
        window.matchMedia('(prefers-color-scheme: dark)').matches
      ) {
        // According to the browser, the user prefers dark mode
        darkMode = true
      }

      // Asyncrhonously store the dark mode preference
      ; (async () => {
        localStorage.setItem('dark', darkMode)
      })()
    }

    if (darkMode) {
      document.querySelector('html').setAttribute('data-dark', darkMode)
      document.querySelector('meta[name=theme-color]')?.setAttribute('content', '#17171d')
    }
  })()
} catch (e) {
  if (e instanceof DOMException) {
    // when used inside the donation iframe, localStorage will throw a DOMException in some browsers that block third-party cookies
  } else {
    throw e
  }
}
