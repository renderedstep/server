import { Controller } from "@hotwired/stimulus"

// THE HEADER STAYS ON SCREEN WITH THE IPHONE KEYBOARD OPEN.
//
// `.page-header` is sticky at `top: 0`, and sticky means the top of the LAYOUT
// viewport. On iOS the keyboard does not shrink the layout viewport: it shrinks
// the visual one and scrolls it down inside the layout one to keep the focused
// input in view, so the header -- pinned to a top the player can no longer
// see -- slides off the screen. `visualViewport.offsetTop` is exactly how far
// the visible top sits below the layout top, so the header is moved down by
// that much. On a desktop, and on any phone with the keyboard shut, it is 0 and
// this changes nothing.
//
// Self-contained on purpose: it is meant to be replaced by pocket-kit's
// viewport pin once that is released, by swapping the `data-controller` name in
// the layout and deleting this file.
export default class extends Controller {
  connect() {
    this.viewport = window.visualViewport
    if (!this.viewport) return

    this.pin = this.pin.bind(this)
    this.viewport.addEventListener("resize", this.pin)
    this.viewport.addEventListener("scroll", this.pin)
    this.pin()
  }

  disconnect() {
    if (!this.viewport) return

    this.viewport.removeEventListener("resize", this.pin)
    this.viewport.removeEventListener("scroll", this.pin)
    this.element.style.removeProperty("transform")
  }

  pin() {
    const offset = Math.max(0, this.viewport.offsetTop)
    if (offset > 0) {
      this.element.style.transform = `translateY(${offset}px)`
    } else {
      this.element.style.removeProperty("transform")
    }
  }
}
