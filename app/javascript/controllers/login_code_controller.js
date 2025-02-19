import { Controller } from '@hotwired/stimulus'

export default class extends Controller {
  static targets = ['wrapper', 'composite', 'input']

  initialize() {
    this.compositeTarget.onkeyup = () => {
      this.compositeTarget.value
        .replace(/[^0-9]/g, '')
        .split('')
        .forEach((char, i) => {
          this.inputTargets[i].value = char
        })
    }

    this.inputTargets.forEach((input, i) => {
      input.onfocus = e => {
        this.handleFocus(i, e)
      }

      input.onpaste = e => {
        e.preventDefault()
        const text =
          e.clipboardData.getData('text')?.replace(/[^0-9]/g, '') || ''
        if (text.length <= 6) {
          this.inputTargets.forEach((input, i) => {
            input.value = text[i]
          })
          this.inputTargets[Math.min(text.length, 5)].focus()
        }
        this.compositeTarget.value = this.inputValues.substring(0, 6)
      }

      input.onkeydown = e => {
        const { key, ctrlKey, altKey, metaKey } = e
        if (key == 'Backspace') {
          if (metaKey || altKey || ctrlKey) {
            this.inputTargets.slice(0, i + 1).forEach(input => {
              input.value = ''
            })
            this.inputTargets[0].focus()
          } else {
            if (this.inputTargets[i].value != '') {
              this.inputTargets[i].value = ''
            } else {
              if (this.inputTargets[i - 1]) {
                this.inputTargets[i - 1].value = ''
              }
            }
            if (this.inputTargets[i - 1]) this.inputTargets[i - 1].select()
          }
          e.preventDefault()
        } else if ('1234567890'.includes(key)) {
          this.inputTargets[i].value = key
          if (this.inputTargets[i + 1]) this.inputTargets[i + 1].select()
          e.preventDefault()
        }

        if (e.target.value.length == 6) {
          const text = e.target.value
          if (text.length <= 6) {
            this.inputTargets.forEach((input, i) => {
              input.value = text[i]
            })
            this.inputTargets[Math.min(text.length, 5)].focus()
          }
          this.compositeTarget.value = text
          return
        }

        this.compositeTarget.value = this.inputValues.substring(0, 6)
        // return false;
        // if (e.keyCode != 91 && e.keyCode != 17) e.preventDefault();
      }
    })
  }

  handleFocus(i, e, select) {
    const n = this.inputValues.length
    if (i == n - 1) {
      this.inputTargets[n - 1].select()
    } else if (i != n) {
      e?.preventDefault?.()
      this.inputTargets[n][select ? 'select' : 'focus']()
      if (i < n) {
        this.inputTargets[i].select()
      }
    }
  }

  get inputValues() {
    return this.inputTargets.map(input => input.value).join('')
  }
}
