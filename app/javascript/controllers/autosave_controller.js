import { Controller } from '@hotwired/stimulus'

export default class extends Controller {
  static targets = ['indicator', 'form'];

  connect () {
    console.log("Connected!");
  }
}