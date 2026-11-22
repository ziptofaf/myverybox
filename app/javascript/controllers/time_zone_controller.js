import { Controller } from "@hotwired/stimulus"

// Sends the browser's time zone along with a datetime-local field (which has
// none), so the server can interpret the entered date and time correctly.
export default class extends Controller {
  static targets = ["field", "label"]

  connect() {
    const zone = Intl.DateTimeFormat().resolvedOptions().timeZone
    if (!zone) return

    this.fieldTarget.value = zone
    if (this.hasLabelTarget) this.labelTarget.textContent = `Time is in your time zone (${zone}).`
  }
}
