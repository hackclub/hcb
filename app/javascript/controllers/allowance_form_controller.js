import { Controller } from '@hotwired/stimulus'

import { USDollar } from '../common/money'

// Previews the spending balance an organizer would be left with after the
// allowance. The amount only counts once it has been typed in, so a value the
// browser restores into the field doesn't show a preview on its own.
export default class extends Controller {
  static targets = ['operation', 'preview', 'projectedBalance']
  static values = { balanceCents: Number }

  amount = ''

  setAmount({ target: { value } }) {
    this.amount = value
    this.update()
  }

  update() {
    const amount = Number(this.amount)
    const operation = this.operationTargets.find(radio => radio.checked)?.value

    this.previewTarget.hidden = !(this.amount !== '' && amount >= 0)
    this.projectedBalanceTarget.textContent = USDollar.format(
      this.balanceCentsValue / 100 + (operation === 'add' ? amount : -amount)
    )
  }
}
