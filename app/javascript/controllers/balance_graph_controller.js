import { Controller } from '@hotwired/stimulus'
import sparkline from '@fnando/sparkline'

export default class extends Controller {
  static targets = ['graph', 'stat', 'balance', 'label', 'sizing', 'size']
  static values = {
    available: Number,
  }
  renderBalance(amount) {
    return (
      ' ' +
      (amount / 100)
        .toLocaleString('en-US', {
          style: 'currency',
          currency: 'USD',
        })
        .replace('$', '')
    )
  }
  connect() {
    fetch(window.location.pathname + '/balance_by_date')
      .then(r => r.json())
      .then(jsonData => {
        const { balanceTrend, balanceByDate: rawBalanceByDate } = jsonData
        this.initial = {
          balance: this.balanceTarget.textContent + '',
        }

        let maxBalance = 0
        let balances = []
        const today = new Date(new Date().setHours(0, 0, 0, 0))
          .toISOString()
          .split('T')[0]

        const entries = Object.entries(rawBalanceByDate)
        entries.sort((a, b) => new Date(b[0]) - new Date(a[0]))
        const balanceByDate = Object.fromEntries(entries)

        for (const date in balanceByDate) {
          const value =
            date == today
              ? this.availableValue
              : parseFloat(balanceByDate[date])

          balances.push({
            date,
            value,
          })

          if (balanceByDate[date] > maxBalance) maxBalance = value
        }

        this.sizingTarget.textContent = this.renderBalance(maxBalance)
        this.graphTarget.setAttribute(
          'width',
          `${this.sizeTarget.clientWidth + 18}px`
        )
        this.statTarget.style.minWidth = `${this.sizeTarget.clientWidth + 24}px`
        this.graphTarget.classList.add(`sparkline--${balanceTrend}`)
        sparkline(this.graphTarget, balances.reverse(), {
          interactive: true,
          onmousemove: this.update.bind(this),
          onmouseout: this.clear.bind(this),
        })
      })
  }
  update(_, { date, value }) {
    this.balanceTarget.textContent = this.renderBalance(value)
    this.labelTarget.textContent = `Account balance on ${new Date(
      date
    ).toLocaleString('en-US', {
      month: 'short',
      day: 'numeric',
      year: 'numeric',
    })}`
  }
  clear() {
    this.labelTarget.textContent = 'Account balance'
    this.balanceTarget.textContent = this.renderBalance(this.availableValue)
  }
}
