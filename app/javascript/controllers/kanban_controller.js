import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  dragstart(event) {
    event.dataTransfer.setData("application_id", event.target.closest("[data-id]").dataset.id)
  }

  dragover(event) {
    event.preventDefault()
  }

  drop(event) {
    event.preventDefault()
    const id = event.dataTransfer.getData("application_id")
    const status = event.target.closest("[data-status]")?.dataset.status
    if (!id || !status) return

    fetch(`/applications/${id}`, {
      method: "PATCH",
      headers: {
        "Content-Type": "application/json",
        "X-CSRF-Token": document.querySelector("meta[name='csrf-token']").content,
        "Accept": "text/vnd.turbo-stream.html"
      },
      body: JSON.stringify({ job_application: { status } })
    }).then(r => r.text()).then(html => {
      window.Turbo.renderStreamMessage(html)
    })
  }
}
