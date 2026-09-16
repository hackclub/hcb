import { Controller } from '@hotwired/stimulus'

export default class extends Controller {
  static values = {
    seconds: { type: Number, default: 30 },
  }

  static targets = ['button', 'countdown']

  connect() {
    this.start()
  }

  disconnect() {
    this.stop()
  }

  sending(event) {
    if (event.target.id !== 'resend-code-form') return
    this.showCountdown('Sending...')
  }

  submitEnd(event) {
    if (event.target.id !== 'resend-code-form') return
    if (event.detail.fetchResponse?.statusCode === 429) {
      this.start(this.secondsValue * 2, 'Too many attempts, try again')
      return
    }
    this.start()
  }

  start(seconds = this.secondsValue, message = null) {
    this.stop()
    this.deadline = Date.now() + seconds * 1000
    this.message = message
    this.tick()
    this.interval = setInterval(() => this.tick(), 1000)
  }

  stop() {
    if (this.interval) clearInterval(this.interval)
    this.interval = null
  }

  tick() {
    this.remaining = Math.max(0, Math.ceil((this.deadline - Date.now()) / 1000))
    if (this.remaining <= 0) {
      this.stop()
      this.showButton()
      return
    }
    this.showCountdown(`${this.message ?? 'Resend code'} (${this.remaining}s)`)
  }

  showCountdown(label) {
    this.countdownTarget.hidden = false
    this.buttonTarget.hidden = true
    this.countdownTarget.textContent = label
  }

  showButton() {
    this.countdownTarget.hidden = true
    this.buttonTarget.hidden = false
  }
}
