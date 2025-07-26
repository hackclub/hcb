import { Controller } from '@hotwired/stimulus'
import gsap from 'gsap'

export default class extends Controller {
  static targets = ['form']

  submit() {
    this.form.requestSubmit()
  }

  reset() {
    this.form.reset()
  }

  keydown(e) {
    if (e.key == 'Escape') {
      this.reset()
      this.submit()
    }
  }

  fill({ params: { values } }) {
    const elementsToAnimate = []

    for (const value in values) {
      const element = document.getElementById(value)
      if (element.type != 'hidden') elementsToAnimate.push(element)
      element.value = values[value]
      element.dispatchEvent(new Event('input'))
    }

    gsap.to(elementsToAnimate, {
      borderColor: '#338eda',
      duration: 0.1,
      stagger: {
        each: 0.05,
        repeat: 1,
        yoyo: true,
      },
      onComplete() {
        elementsToAnimate.forEach(el => {
          el.style.borderColor = null
        })
      },
    })
  }

  /**
   * @returns {HTMLFormElement}
   */
  get form() {
    if (this.hasFormTarget) {
      return this.formTarget
    } else {
      return this.element
    }
  }
}
