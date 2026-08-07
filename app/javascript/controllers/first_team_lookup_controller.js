import { Controller } from '@hotwired/stimulus'
import { debounce } from 'lodash/function'

export default class extends Controller {
  static targets = ['league', 'teamNumber', 'teamName']

  connect() {
    this.lookup = debounce(this._lookup, 500)
  }

  async _lookup() {
    const league = this.leagueTarget.value
    const teamNumber = this.teamNumberTarget.value

    if (!league || !teamNumber) return

    if (league == 'ftc' || league == 'fll') return

    let value = this.teamNameTarget.value
    this.setLoading(true)

    try {
      const response = await fetch(
        `/first/team?league=${encodeURIComponent(league)}&team_number=${encodeURIComponent(teamNumber)}`
      )
      if (!response.ok) return

      const data = await response.json()
      value = data.team_name
    } catch {
      // silently ignore lookup failures
    } finally {
      this.setLoading(false, value)
    }
  }

  setLoading(loading, value) {
    this.teamNameTarget.disabled = loading

    if (loading) {
      this.teamNameTarget.value = 'Loading...'
    } else {
      this.teamNameTarget.value = value
    }
  }
}
