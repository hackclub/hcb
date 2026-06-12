import { ApplicationController, useDebounce } from 'stimulus-use'

export default class extends ApplicationController {
  static targets = [
    'savingIndicator',
    'savedIndicator',
    'errorIndicator',
    'form',
  ]
  static debounces = ['save']

  connect() {
    useDebounce(this, { wait: 750 })
  }

  save() {
    this.toggleIndicator('saving')

    const data = new FormData(this.formTarget)
    data.append('autosave', true)

    fetch(this.formTarget.action, {
      method: 'PATCH',
      body: data,
    })
      .then(res => {
        if (res.ok) {
          setTimeout(() => {
            this.toggleIndicator('saved')
          }, 1000)
        } else {
          throw res
        }
      })
      .catch(() => {
        this.toggleIndicator('error')
      })
  }

  toggleIndicator(status) {
    switch (status) {
      case 'saving':
        this.savingIndicatorTarget.style = ''
        this.savedIndicatorTarget.style = 'display: none;'
        this.errorIndicatorTarget.style = 'display: none;'
        break
      case 'saved':
        this.savingIndicatorTarget.style = 'display: none;'
        this.savedIndicatorTarget.style = ''
        this.errorIndicatorTarget.style = 'display: none;'
        break
      case 'error':
        this.savingIndicatorTarget.style = 'display: none;'
        this.savedIndicatorTarget.style = 'display: none;'
        this.errorIndicatorTarget.style = ''
        break
    }
  }
}
