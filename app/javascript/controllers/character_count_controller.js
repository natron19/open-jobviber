import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["input", "counter"]
  static values = { max: Number }

  connect() {
    this.updateCounter()
  }

  update() {
    this.updateCounter()
  }

  updateCounter() {
    this.counterTarget.textContent = this.maxValue - this.inputTarget.value.length
  }
}
