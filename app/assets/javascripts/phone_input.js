;(() => {
  const phoneInputField = document.querySelector('#phone_raw')
  const phoneNumberField = document.querySelector('#phone_number')
  
  const phoneInput = window.intlTelInput(phoneInputField, {
    initialCountry: 'us',
    preferredCountries: ['us', 'in', 'ca', 'sg', 'au', 'gb'],
    utilsScript:
      'https://cdnjs.cloudflare.com/ajax/libs/intl-tel-input/17.0.8/js/utils.js'
  })

  const persistedPhoneNumber = phoneInputField.dataset.persistedPhoneNumber || ''

  const updatePhoneNumber = () => {
    phoneNumberField.value = phoneInput.getNumber()

    const phoneNumberChanged = phoneNumberField.value !== persistedPhoneNumber
    
    const unverifiedMessage = document.querySelector('#unverified-phone-message')
    const changedMessage = document.querySelector('#unsaved-phone-message')

    if (unverifiedMessage) {
      unverifiedMessage.style.display = phoneNumberChanged ? 'none' : ''
    }

    if (changedMessage) {
      changedMessage.style.display = phoneNumberChanged ? '' : 'none'
    }
  }

  window.onsubmit = updatePhoneNumber
  phoneInputField.addEventListener('input', updatePhoneNumber)
  phoneInputField.addEventListener('blur', updatePhoneNumber)
})()
