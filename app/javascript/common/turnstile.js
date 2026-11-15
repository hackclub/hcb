const SCRIPT_URL =
  'https://challenges.cloudflare.com/turnstile/v0/api.js?render=explicit'

let loader

// Loads Cloudflare's script once per page and resolves with the global it
// defines. Every caller shares the one promise, so a page with more than one
// widget still fetches the script a single time.
//
// We render explicitly rather than letting the script scan for `.cf-turnstile`
// elements: the widget mounts inside a modal after page load, which the
// automatic scan never sees.
export default function loadTurnstile() {
  if (!loader) {
    loader = new Promise((resolve, reject) => {
      if (window.turnstile) {
        resolve(window.turnstile)
        return
      }

      const script = document.createElement('script')
      script.src = SCRIPT_URL
      script.async = true
      script.defer = true
      script.onload = () => resolve(window.turnstile)
      script.onerror = () => {
        // Clear the cached promise so a later attempt can retry the fetch.
        loader = undefined
        reject(new Error('Failed to load Turnstile'))
      }
      document.head.appendChild(script)
    })
  }

  return loader
}
