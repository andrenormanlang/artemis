import { Controller } from "@hotwired/stimulus";

// Fills hidden latitude/longitude fields on the sign-up form using the
// browser's geolocation. Entirely optional — if the user denies access or it
// fails, the fields stay blank and the server applies a default location.
export default class extends Controller {
  static targets = ["latitude", "longitude", "status"];

  connect() {
    if (!("geolocation" in navigator)) {
      this.setStatus("Geolocalização indisponível — usaremos uma localização padrão.");
      return;
    }

    navigator.geolocation.getCurrentPosition(
      (position) => {
        this.latitudeTarget.value = position.coords.latitude;
        this.longitudeTarget.value = position.coords.longitude;
        this.setStatus("Localização detectada — seu boletim será personalizado. ✓");
      },
      () => {
        this.setStatus("Sem acesso à localização — tudo bem, usaremos uma localização padrão.");
      },
      { enableHighAccuracy: false, timeout: 8000, maximumAge: 600000 },
    );
  }

  setStatus(text) {
    if (this.hasStatusTarget) {
      this.statusTarget.textContent = text;
    }
  }
}
