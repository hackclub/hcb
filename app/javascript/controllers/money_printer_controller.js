import { Controller } from '@hotwired/stimulus'
import { gsap } from 'gsap'

const usd = new Intl.NumberFormat('en-US', {
  style: 'currency',
  currency: 'USD',
  minimumFractionDigits: 2,
  maximumFractionDigits: 2,
})
const count = new Intl.NumberFormat('en-US')

// The stats cron runs on 15-minute wall-clock boundaries (:00/:15/:30/:45) and
// the job takes ~2 min. A loaded tab reloads at the next boundary plus this
// buffer, so it lands right after fresh stats are written (and replays the
// print animation). Boundaries align to the epoch, which matches UTC clock
// quarter-hours, so `Date.now() % QUARTER` needs no timezone handling.
const REFRESH_QUARTER_MS = 15 * 60 * 1000
const REFRESH_BUFFER_MS = 3 * 60 * 1000
const REFRESH_MIN_MS = 30 * 1000

// Both on-screen rotators (the gen-z ticker and the money-to-stuff converter)
// share this cadence so they swap in unison.
const ROTATE_INTERVAL_MS = 3000
const ROTATE_FADE_MS = 380

// Rotating one-liners. Index 0 matches the server-seeded line so the swap-in
// is seamless. Kept current as of early 2026.
const PHRASES = {
  printing: [
    'money printer go brrr 💸', // index 0 must match the server-seeded line
    'lowkey an infinite money glitch',
    'chat, is this real money? 💀',
    "it's giving Federal Reserve",
    'no cap, we printed this',
    'the treasury is cooking 🔥',
    "we're so back 📈",
    '+aura for the balance sheet',
    'the money is mathing 🧮',
    'quantitative easing? in this economy? 😌',
    'we let the printer cook 👨‍🍳',
    'stonks only go up 📊',
    'printing money on easy mode 🎮',
    'money speedrun, any% 🏁',
    "it's giving central-bank arc",
    'balance sheet? more like balance cheat',
    'this printer has that dawg in it 🐕',
    'gng we are NOT broke 🙏',
    'infinite glitch confirmed',
    'the Fed could never 🖨️',
    'they said it could not be done. brrr.',
    'this is bussin fr 🤑',
    'delulu is the solulu (we are rich)',
    'caught in 4k printing cash 📸',
    'number go up, serotonin go up 🧠',
  ],
  shredding: [
    "we're so cooked 💀", // index 0 must match the server-seeded line
    "the math ain't mathing",
    'aura: catastrophically negative',
    "it's giving recession",
    'money? never heard of her',
    'straight to the shredder 🗑️',
    'down bad fr fr',
    'rip the treasury 🪦',
    'it\'s giving "we have money at home"',
    'stonks found the basement 📉',
    'gng where did it all go 😔',
    'this is NOT bussin',
    'we were never back 💔',
    'delulu was not the solulu',
    'financial fumble of the century 🤡',
    'caught in 4k losing it all 📸',
    'the vibes are recessionary',
    'brokie arc, unfortunately',
    'number go down, serotonin go down 🧠',
    'crashout incoming 🚨',
    "it's giving Great Depression cosplay",
    'money said "I\'m out" ✌️',
    'the bank account is in shambles',
    'the bag was NOT secured 💼',
    'the ledger said "it\'s over" 😭',
  ],
  jammed: [
    'perfectly balanced. no notes.', // index 0 must match the server-seeded line
    'the engines are locked in 🔒',
    'zero discrepancy. we ate. 🍽️',
    'balanced, as all things should be ⚖️',
    "it's giving accuracy 💯",
    'the math is finally mathing',
    'no cap, the books are clean',
    'peak reconciliation behavior',
    "flawless. chef's kiss. 🤌",
    'the ledgers are besties 🤝',
  ],
}

// What that money is "worth" in things, priced in USD. The Hack Club / YSWS
// values are cited to the YSWS economics handbook (the hackclub/ysws-docs repo);
// the rest are absurd-scale universals. Kept current for early 2026.
const EQUIVALENTS = [
  // Hack Club / YSWS (paths are relative to the ysws-docs repo):
  { emoji: '✈️', label: 'hackathon flights', price: 200 }, // economics/hcb/README.md:141
  { emoji: '🛠️', label: 'weighted projects funded', price: 85 }, // economics/basics-of-the-economy.md:19
  { emoji: '⌨️', label: 'hours of teen coding', price: 8.5 }, // economics/basics-of-the-economy.md:19
  { emoji: '🚀', label: 'YSWS program starter budgets', price: 1000 }, // economics/basics-of-the-economy.md:5
  { emoji: '🍕', label: 'reimbursed hackathon meals', price: 20 }, // policies/travel-and-event-attendance-policy.md:57
  { emoji: '🔧', label: 'employee hardware budgets', price: 2000 }, // economics/basics-of-the-economy.md:7
  { emoji: '📦', label: 'international packages shipped', price: 14 }, // shipping-physical-things.md:13
  { emoji: '✉️', label: 'sticker letters mailed out', price: 3 }, // shipping-physical-things.md:13
  // Absurd-scale universals, for the bit:
  { emoji: '🧸', label: 'Labubus', price: 30 },
  { emoji: '🌭', label: 'Costco hot dog combos', price: 1.5 },
  { emoji: '🧋', label: 'boba teas', price: 6 },
  { emoji: '🌯', label: 'Chipotle burritos', price: 10 },
  { emoji: '🎧', label: 'years of Spotify Premium', price: 143.88 },
  { emoji: '🥤', label: 'Erewhon smoothies', price: 20 },
  { emoji: '📱', label: 'iPhones', price: 999 },
]

export default class extends Controller {
  static targets = ['counter', 'ticker', 'equivalent']
  static values = {
    netDelta: Number, // signed cents
    mode: String,
    warming: Boolean,
  }

  connect() {
    this.reduced = window.matchMedia('(prefers-reduced-motion: reduce)').matches

    if (this.warmingValue) {
      this.startWarming()
      return
    }

    this.runPrinter()
    this.buildRotators()
    this.startRotating()
    this.startVisibilityPauses()
    this.reloadTimer = setTimeout(
      () => window.location.reload(),
      this.alignedReloadDelay()
    )
  }

  disconnect() {
    if (this.tween) this.tween.kill()
    if (this.reloadTimer) clearTimeout(this.reloadTimer)
    if (this.rotTimer) clearTimeout(this.rotTimer)
    if (this.rotFadeTimer) clearTimeout(this.rotFadeTimer)
    if (this.onVisibility)
      document.removeEventListener('visibilitychange', this.onVisibility)
  }

  // Milliseconds until just after the next cron computation completes.
  alignedReloadDelay() {
    const intoQuarter = Date.now() % REFRESH_QUARTER_MS
    const delay =
      intoQuarter < REFRESH_BUFFER_MS
        ? REFRESH_BUFFER_MS - intoQuarter
        : REFRESH_QUARTER_MS - intoQuarter + REFRESH_BUFFER_MS
    return Math.max(delay, REFRESH_MIN_MS)
  }

  // Cold-cache state: idle pulse + auto-refresh so the number appears once the
  // job has populated the cache.
  startWarming() {
    if (!this.reduced) {
      this.tween = gsap.to(this.counterTarget, {
        opacity: 0.35,
        duration: 0.9,
        repeat: -1,
        yoyo: true,
        ease: 'sine.inOut',
      })

      this.onVisibility = () => {
        if (!this.tween) return
        document.hidden ? this.tween.pause() : this.tween.resume()
      }
      document.addEventListener('visibilitychange', this.onVisibility)
    }

    this.reloadTimer = setTimeout(() => window.location.reload(), 6000)
  }

  // Loaded state: "print" the figure by rolling the odometer from 0 to the
  // absolute net delta. Sign/mode coloring is handled server-side via CSS class.
  runPrinter() {
    const cents = Math.abs(this.netDeltaValue)

    if (this.reduced) {
      this.counterTarget.textContent = usd.format(cents / 100)
      return
    }

    const proxy = { value: 0 }
    this.tween = gsap.to(proxy, {
      value: cents,
      duration: 2.2,
      ease: 'power3.out',
      onUpdate: () => {
        this.counterTarget.textContent = usd.format(proxy.value / 100)
      },
      onComplete: () => {
        this.counterTarget.textContent = usd.format(cents / 100)
      },
    })

    // Subtle paper-feed shudder as it prints.
    gsap.fromTo(
      this.counterTarget,
      { y: -8, filter: 'blur(2px)' },
      { y: 0, filter: 'blur(0px)', duration: 0.6, ease: 'power2.out' }
    )
  }

  // Seed both rotators with their first entry (the ticker is also seeded
  // server-side; the converter replaces its placeholder here).
  buildRotators() {
    this.phrases = this.hasTickerTarget ? PHRASES[this.modeValue] || [] : []
    if (this.phrases.length) this.tickerTarget.textContent = this.phrases[0]

    this.equivalents = []
    if (this.hasEquivalentTarget) {
      const dollars = Math.abs(this.netDeltaValue) / 100
      this.equivalents = EQUIVALENTS.map(
        e =>
          `that's ${count.format(Math.round(dollars / e.price))} ${e.label} ${e.emoji}`
      )
      this.equivalentTarget.textContent = this.equivalents[0]
    }

    this.rotIndex = 0
  }

  startRotating() {
    if (this.reduced || !this.canRotate()) return

    this.rotating = true
    this.scheduleRotate()
  }

  canRotate() {
    return this.phrases.length > 1 || this.equivalents.length > 1
  }

  // One timer advances both rotators together so they swap in unison. A shared
  // index modulo each list keeps the fade synchronized even though the lists
  // differ in length.
  scheduleRotate() {
    this.rotTimer = setTimeout(() => {
      if (!this.rotating) return

      this.rotIndex += 1

      if (this.phrases.length > 1) this.tickerTarget.style.opacity = '0'
      if (this.equivalents.length > 1) this.equivalentTarget.style.opacity = '0'

      this.rotFadeTimer = setTimeout(() => {
        if (this.phrases.length > 1) {
          this.tickerTarget.textContent =
            this.phrases[this.rotIndex % this.phrases.length]
          this.tickerTarget.style.opacity = '1'
        }
        if (this.equivalents.length > 1) {
          this.equivalentTarget.textContent =
            this.equivalents[this.rotIndex % this.equivalents.length]
          this.equivalentTarget.style.opacity = '1'
        }
      }, ROTATE_FADE_MS)

      this.scheduleRotate()
    }, ROTATE_INTERVAL_MS)
  }

  // Pause both rotators while the tab is hidden; resume on return.
  startVisibilityPauses() {
    this.onVisibility = () => {
      if (document.hidden) {
        this.rotating = false
      } else if (!this.rotating && !this.reduced && this.canRotate()) {
        this.rotating = true
        this.scheduleRotate()
      }
    }
    document.addEventListener('visibilitychange', this.onVisibility)
  }
}
