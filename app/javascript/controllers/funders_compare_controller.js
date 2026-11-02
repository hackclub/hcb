import { Controller } from '@hotwired/stimulus'

// Comparison table: HCB vs. private foundation vs. donor-advised fund. Each row can
// expand to an evidence-rich explanation with sources.
//
// Progressive enhancement in reverse: the detail rows are rendered EXPANDED in the
// server HTML, so AI crawlers and no-JS visitors read every fact and source (AI
// crawlers don't run JS — what's in the raw HTML is what they can cite). This
// controller COLLAPSES the details once JS is running, then toggles them per row.
// Nothing is hidden at the source; it's only collapsed after enhancement.
//
// `is-enhanced` on the root gates the affordances (chevron + pointer cursor) so a
// no-JS visitor never sees a control that does nothing. `is-stuck` is toggled while
// the sticky header is parked under the nav, so it can show a drop shadow (a no-JS
// table just scrolls without the stuck styling).
export default class extends Controller {
  static targets = ['toggle', 'detail', 'sentinel', 'switchOpt']

  connect() {
    this.element.classList.add('is-enhanced')
    this.toggleTargets.forEach((_, i) => this.setExpanded(i, false))
    // On mobile the table shows HCB vs. one alternative at a time; default to the private foundation.
    // With no JS, no data-compare is set and the full table (all columns) renders.
    if (this.hasSwitchOptTarget) this.setCompare('pf')
    this.watchStuck()
  }

  // Mobile "compare against" segmented control: pick which alternative sits beside HCB.
  compareAgainst(event) {
    this.setCompare(event.currentTarget.dataset.vehicle)
  }

  setCompare(vehicle) {
    this.element.dataset.compare = vehicle
    this.switchOptTargets.forEach(opt => {
      const active = opt.dataset.vehicle === vehicle
      opt.classList.toggle('is-active', active)
      opt.setAttribute('aria-pressed', String(active))
    })
  }

  disconnect() {
    this.stuckObserver?.disconnect()
  }

  toggle(event) {
    const i = this.toggleTargets.indexOf(event.currentTarget)
    if (i === -1) return
    const expanded =
      event.currentTarget.getAttribute('aria-expanded') === 'true'
    this.setExpanded(i, !expanded)
  }

  setExpanded(index, expanded) {
    const toggle = this.toggleTargets[index]
    const detail = this.detailTargets[index]
    toggle.setAttribute('aria-expanded', expanded ? 'true' : 'false')
    if (detail) detail.hidden = !expanded
  }

  // The sentinel sits at the top of the table; once it scrolls above the nav line the
  // sticky header is "stuck", so we flag the root for the drop-shadow styling.
  watchStuck() {
    if (!this.hasSentinelTarget) return
    this.stuckObserver = new IntersectionObserver(
      ([entry]) =>
        this.element.classList.toggle('is-stuck', !entry.isIntersecting),
      { rootMargin: '-64px 0px 0px 0px', threshold: 0 }
    )
    this.stuckObserver.observe(this.sentinelTarget)
  }
}
