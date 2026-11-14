import { Controller } from '@hotwired/stimulus'

export default class extends Controller {
  static targets = ['carousel', 'left', 'right']
  static values = {
    slide: Number,
    length: Number,
  }

  connect() {
    this.leftTarget.addEventListener('click', () => {
      this.previous()
    })
    this.rightTarget.addEventListener('click', () => {
      this.next()
    })
  }

  previous() {
    if (this.slideValue <= 0) return (this.slideValue = 0)
    this.slideValue--
    this.setActiveSlide(this.slideValue)
  }

  next() {
    if (this.slideValue >= this.lengthValue - 1)
      return (this.slideValue = this.lengthValue - 1)
    this.slideValue++
    this.setActiveSlide(this.slideValue)
  }

  setActiveSlide(slideNumber) {
    const carouselItems =
      this.carouselTarget.querySelectorAll('.carousel__item')
    carouselItems.forEach(item =>
      item.classList.remove('carousel__item--active')
    )
    carouselItems[slideNumber].classList.add('carousel__item--active')
    const carouselWrapper = this.carouselTarget.closest('.carousel__wrapper')
    carouselWrapper.querySelector('.carousel__number').innerText =
      slideNumber + 1
  }
}
