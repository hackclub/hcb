; (async () => {
  const csrfTokenSelector = document.querySelector('[name=csrf-token]')
  let token = ''
  if (csrfTokenSelector && csrfTokenSelector.content) {
    // eslint-disable-next-line no-unused-vars
    token = csrfTokenSelector.content
  }

  const fp = await import('https://openfpcdn.io/fingerprintjs/v3').then(
    FingerprintJS => FingerprintJS.load()
  )
  const result = await fp.get()

  // eslint-disable-next-line no-undef
  const parser = new UAParser()
  const visitorId = result.visitorId
  parser.setUA(navigator.userAgent)
  const uaParserResult = parser.getResult()

  document.querySelector('#fingerprint').value = visitorId
  document.querySelector('#device_info').value =
    uaParserResult.browser.name + ' ' + uaParserResult.browser.version
  document.querySelector('#os_info').value =
    uaParserResult.os.name + ' ' + uaParserResult.os.version
  document.querySelector('#timezone').value = result.components.timezone.value
})()
