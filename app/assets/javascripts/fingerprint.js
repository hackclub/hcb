; (async () => {
  const csrfTokenSelector = document.querySelector('[name=csrf-token]')
  let token = ''
  if (csrfTokenSelector && csrfTokenSelector.content) {
    // eslint-disable-next-line no-unused-vars
    token = csrfTokenSelector.content
  }

  const fp = await import('https://cdn.jsdelivr.net/npm/@fingerprintjs/fingerprintjs@3.X/+esm').then(
    FingerprintJS => FingerprintJS.load()
  )
  const result = await fp.get()
  const visitorId = result.visitorId

  document.querySelector('#fingerprint').value = visitorId
  document.querySelector('#device_info').value = $.ua.browser.name + ' ' + $.ua.browser.version
  document.querySelector('#os_info').value = $.ua.os.name + ($.ua.os.version ? ' ' + $.ua.os.version : '')
  document.querySelector('#timezone').value = result.components.timezone.value
})()
