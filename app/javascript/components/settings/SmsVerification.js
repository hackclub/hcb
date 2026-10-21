import csrf from '../../common/csrf'
import loadTurnstile from '../../common/turnstile'
import React, { useEffect, useRef, useState } from 'react'
import PropTypes from 'prop-types'

// Must match TurnstileService::SMS_VERIFICATION_ACTION.
const TURNSTILE_ACTION = 'sms-verification'

function renderPhoneNumber(phoneNumber) {
  if (phoneNumber.substring(0, 2) != '+1' || phoneNumber.length != 12)
    return phoneNumber
  let areaCode = phoneNumber.substring(2, 5)
  let middleThree = phoneNumber.substring(5, 8)
  let lastFour = phoneNumber.substring(8)
  return `+1 (${areaCode}) ${middleThree}-${lastFour}`
}

const SmsVerification = ({
  phoneNumber,
  enrollSmsAuth = false,
  turnstileSitekey = null,
}) => {
  const [errors, setErrors] = useState([])
  const [validationSent, setValidationSent] = useState(false)
  const [validationSuccess, setValidationSuccess] = useState(false)
  const [loading, setLoading] = useState(false)
  const [turnstileReady, setTurnstileReady] = useState(false)
  const [code, setCode] = useState('')
  const verificationCodeInput = useRef(null)
  const turnstileContainer = useRef(null)
  const turnstileWidgetId = useRef(null)

  // Both throw if the widget's element has already gone away, which React can
  // do underneath us when this step of the modal unmounts.
  const withTurnstileWidget = fn => {
    if (turnstileWidgetId.current === null) return
    try {
      fn(turnstileWidgetId.current)
    } catch {
      turnstileWidgetId.current = null
    }
  }

  // Render the widget once, when a sitekey is configured. This component mounts
  // inside a modal, so Cloudflare's automatic scan never sees it. The render
  // also has to wait until the modal opens: the widget comes up blank and the
  // challenge never runs if it renders into a display:none container.
  useEffect(() => {
    if (!turnstileSitekey || !turnstileContainer.current) return undefined

    let removed = false

    // Render a fresh widget on every open, not just the first: jquery-modal
    // re-appends the modal element to its blocker each time it opens, and
    // moving an iframe in the DOM reloads it, killing an existing widget.
    const observer = new IntersectionObserver(entries => {
      if (!entries.some(entry => entry.isIntersecting)) return

      loadTurnstile()
        .then(turnstile => {
          if (removed) return
          withTurnstileWidget(id => turnstile.remove(id))
          setTurnstileReady(false)
          turnstileWidgetId.current = turnstile.render(
            turnstileContainer.current,
            {
              sitekey: turnstileSitekey,
              action: TURNSTILE_ACTION,
              callback: () => setTurnstileReady(true),
              'expired-callback': () => setTurnstileReady(false),
              'error-callback': () => setTurnstileReady(false),
            }
          )
        })
        .catch(() =>
          setErrors(["We couldn't load the human-verification check."])
        )
    })
    observer.observe(turnstileContainer.current)

    return () => {
      removed = true
      observer.disconnect()
      withTurnstileWidget(id => window.turnstile?.remove(id))
      turnstileWidgetId.current = null
    }
  }, [turnstileSitekey])

  // Sending needs a token, so hold the send/resend controls until the widget
  // has produced one.
  const awaitingTurnstile = !!turnstileSitekey && !turnstileReady

  const handleClick = async e => {
    e.preventDefault()
    if (loading || awaitingTurnstile) {
      return
    }
    setLoading(true)
    try {
      const body = {}
      if (turnstileSitekey) {
        const token =
          turnstileWidgetId.current === null
            ? null
            : window.turnstile?.getResponse(turnstileWidgetId.current)

        if (!token) {
          setErrors(['Please complete the verification check, then try again.'])
          return
        }

        body['cf-turnstile-response'] = token
      }

      const resp = await fetch('/users/start_sms_auth_verification', {
        method: 'POST',
        headers: {
          'X-CSRF-Token': csrf(),
          'Content-Type': 'application/json',
          Accept: 'application/json',
        },
        body: JSON.stringify(body),
      })
      const json = await resp.json()

      if (resp.ok) {
        setErrors([])
        setValidationSent(true)
      } else {
        setErrors([json.error || 'something went wrong!'])
      }
    } finally {
      // Tokens are single-use, so "Resend code" needs a fresh one either way.
      withTurnstileWidget(id => window.turnstile?.reset(id))
      setTurnstileReady(false)
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
                  className={
                    loading || awaitingTurnstile ? 'muted wait' : 'pointer'
                  }
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
                disabled={awaitingTurnstile}
                className={
                  loading || awaitingTurnstile
                    ? 'bg-muted wait btn'
                    : 'bg-info btn'
                }
              >
                Send verification code
              </button>
            </>
          )}
          {/* Stays mounted across both steps so "Resend code" can reuse it. */}
          <div ref={turnstileContainer} className="mt1" />
        </>
      )}
    </>
  )
}

SmsVerification.propTypes = {
  phoneNumber: PropTypes.string.isRequired,
  enrollSmsAuth: PropTypes.bool,
  turnstileSitekey: PropTypes.string,
}

export default SmsVerification
