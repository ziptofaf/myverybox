import { Controller } from "@hotwired/stimulus"

// Copies the value of the "source" target to the clipboard.
export default class extends Controller {
  static targets = ["source", "button"]

  async copy() {
    const text = this.sourceTarget.value

    try {
      await navigator.clipboard.writeText(text)
    } catch {
      // Clipboard API unavailable (e.g. plain http): fall back to selection.
      this.sourceTarget.select()
      document.execCommand("copy")
    }

    this.buttonTarget.textContent = "Copied!"
    clearTimeout(this.resetTimer)
    this.resetTimer = setTimeout(() => { this.buttonTarget.textContent = "Copy" }, 2000)
  }

  select() {
    this.sourceTarget.select()
  }

  disconnect() {
    clearTimeout(this.resetTimer)
  }
}
