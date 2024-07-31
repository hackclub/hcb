import csrf from '../../common/csrf'
import React, { useEffect, useRef, useState } from 'react'
import PropTypes from 'prop-types'

function renderPhoneNumber(phoneNumber) {
  if (phoneNumber.substring(0, 2) != '+1' || phoneNumber.length != 12)
    return phoneNumber
  let areaCode = phoneNumber.substring(2, 5)
  let middleThree = phoneNumber.substring(5, 8)
  let lastFour = phoneNumber.substring(8)
  return `+1 (${areaCode}) ${middleThree}-${lastFour}`
}

const SmsVerification = ({ phoneNumber, enrollSmsAuth = false }) => {
  const [errors, setErrors] = useState([])
  const [validationSent, setValidationSent] = useState(false)
  const [validationSuccess, setValidationSuccess] = useState(false)
  const [loading, setLoading] = useState(false)
  const [code, setCode] = useState('')
  const verificationCodeInput = useRef(null)

  const handleClick = async e => {
    e.preventDefault()
    if (loading) {
      return
    }
    setLoading(true)
    try {
      const resp = await fetch('/users/start_sms_auth_verification', {
        method: 'POST',
        headers: { 'X-CSRF-Token': csrf() },
      })

      if (resp.ok) {
        setErrors([])
        setValidationSent(true)
      } else {
        setErrors(['something went wrong!'])
      }
    } finally {
      setLoading(false)
    }
  }

  useEffect(() => {
    if (validationSent) {
      verificationCodeInput.current.focus()
    }
  }, [validationSent])

  const handleSubmit = async e => {
    console.log('submitting...')
    if (e) {
      e.preventDefault()
    }
    setLoading(true)
    const resp = await fetch('/users/complete_sms_auth_verification', {
      method: 'POST',
      headers: { 'X-CSRF-Token': csrf(), 'Content-Type': 'application/json' },
      body: JSON.stringify({ code, enroll_sms_auth: enrollSmsAuth }),
    })

    if (resp.ok) {
      setErrors([])
      setValidationSuccess(true)
    } else {
      setErrors(['⚠️ Invalid code. Did you type it in correctly?'])
    }

    setLoading(false)
  }

  const handleInput = e => {
    setCode(e.target.value)
    if (e.key === 'Enter' || e.keyCode === 13) {
      handleSubmit(e)
    }
  }

  const refresh = () => {
    window.location.reload()
  }

  return (
    <>
      {errors.length > 0 && (
        <ul
          className="list-reset bg-error p1 rounded"
          style={{ color: 'white' }}
        >
          {errors.map((e, i) => (
            <li key={i}>{e}</li>
          ))}
        </ul>
      )}
      {validationSuccess && (
        <>
          <p>
            ✅ Verified!{' '}
            {enrollSmsAuth &&
              `Next time you sign in your login code will go to ${renderPhoneNumber(
                phoneNumber
              )}.`}
          </p>
          <button className="btn btn-success" onClick={refresh}>
            Refresh to continue
          </button>
        </>
      )}
      {!validationSuccess && (
        <>
          {validationSent ? (
            <>
              <p>
                We&apos;ve just sent a code to {renderPhoneNumber(phoneNumber)}.
                It should arrive in the next 5 to 30 seconds depending on your
                connection.
              </p>
              <div className="flex">
                <form onSubmit={handleSubmit}>
                  <input
                    type="tel"
                    ref={verificationCodeInput}
                    autoComplete="off"
                    onSubmit={handleSubmit}
                    onInput={handleInput}
                    placeholder="XXX-XXX"
                    value={code}
                    className="mb1"
                    required
                  />
                  <input
                    className={loading ? 'muted wait disabled' : 'pointer'}
                    onSubmit={handleSubmit}
                    type="submit"
                    value="Verify"
                  />
                </form>
              </div>
              <p>
                <a
                  href="#"
                  onClick={handleClick}
                  className={loading ? 'muted wait' : 'pointer'}
                >
                  Resend code
                </a>{' '}
                to {renderPhoneNumber(phoneNumber)}.
              </p>
            </>
          ) : (
            <>
              <p>
                To verify your phone number, we&apos;ll send a code to{' '}
                {renderPhoneNumber(phoneNumber)}.
              </p>
              <button
                onClick={handleClick}
                className={loading ? 'bg-muted wait btn' : 'pointer btn'}
              >
                Send Verification Code
              </button>
            </>
          )}
        </>
      )}
    </>
  )
}

SmsVerification.propTypes = {
  phoneNumber: PropTypes.string.isRequired,
  enrollSmsAuth: PropTypes.bool,
}

export default SmsVerification
