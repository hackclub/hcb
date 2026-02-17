;(() => {
  const phoneInputField = document.querySelector('#phone_raw')
  const phoneInput = window.intlTelInput(phoneInputField, {
    initialCountry: 'us',
    preferredCountries: ['us', 'in', 'ca', 'sg', 'au', 'gb'],
    utilsScript:
      'https://cdnjs.cloudflare.com/ajax/libs/intl-tel-input/17.0.8/js/utils.js'
  })
  const callback = () => {
    document.getElementById('phone_number').value = phoneInput.getNumber()
    return true
  }

  window.onsubmit = callback
  phoneInputField.onblur = callback
})()
