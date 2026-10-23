import { Controller } from "@hotwired/stimulus"

// THE FEEDBACK DIALOG: opens and closes a native <dialog>, and nothing else.
// Sending is an ordinary form post answered with a Turbo Stream -- see
// `FeedbackNotesController`.
export default class extends Controller {
  static targets = [ "dialog" ]

  open() {
    this.dialogTarget.showModal()
  }

  close() {
    this.dialogTarget.close()
  }
}
