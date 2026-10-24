import { Controller } from "@hotwired/stimulus"

// THE FEEDBACK DIALOG: opens and closes a native <dialog>, and on submit fills
// in what this browser says about the device it runs on. Sending is an ordinary
// form post answered with a Turbo Stream -- see `FeedbackNotesController`,
// which checks and caps every one of these before any of it is sent on.
export default class extends Controller {
  static targets = [ "dialog", "device" ]

  open() {
    this.dialogTarget.showModal()
  }

  close() {
    this.dialogTarget.close()
  }

  describe() {
    const viewport = window.visualViewport
    const values = {
      user_agent: navigator.userAgent,
      screen: `${screen.width}x${screen.height}`,
      viewport: `${window.innerWidth}x${window.innerHeight}`,
      visual_viewport: viewport ? `${Math.round(viewport.width)}x${Math.round(viewport.height)}` : "",
      pixel_ratio: String(window.devicePixelRatio),
      standalone: String(window.matchMedia("(display-mode: standalone)").matches || navigator.standalone === true),
      color_scheme: window.matchMedia("(prefers-color-scheme: light)").matches ? "light" : "dark"
    }
    this.deviceTargets.forEach((input) => { input.value = values[input.dataset.field] ?? "" })
  }
}
