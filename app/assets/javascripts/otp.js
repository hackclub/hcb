function setupOTP() {
  $('[data-behavior=otp_input]').on('keydown', (e) => {
    switch (event.key) {
        case "ArrowLeft":
            e.target.style.setProperty('--_otp-digit', Math.max(0, e.target.selectionStart - 1))
            break;
        case "ArrowRight":
            e.target.style.setProperty('--_otp-digit', Math.min(e.target.value.length, e.target.selectionStart + 1))
            break;
    }
  })
  
  $('[data-behavior=otp_input]').on('input', (e) => {
    e.target.style.setProperty('--_otp-digit', e.target.selectionStart)
    if(e.target.value.length == 6){
      $(e.target).closest('form').submit();
    }
    if(isNaN(e.target.value)){
      e.target.style.animation = e.target.style.animation 
      ? e.target.style.animation + ',0.5s linear shake' // shake multiple times!
      : '0.5s linear shake'
    }
  })
  
  $('[data-behavior=otp_input]').on('click', (e) => 
    e.target.style.setProperty('--_otp-digit', e.target.selectionStart)
  )
}

setupOTP()

document.addEventListener('turbo:load', setupOTP)
