import { Controller } from "@hotwired/stimulus";

export default class extends Controller {
  static targets = ["loadingText", "loadingSubtext"];

  connect() {
    this.requestLocation();
  }

  requestLocation() {
    if (navigator.geolocation) {
      navigator.geolocation.getCurrentPosition(
        (position) => {
          const lat = position.coords.latitude;
          const lng = position.coords.longitude;

          window.location.href = `/moon?lat=${lat}&lng=${lng}`;
        },
        (error) => {
          console.error("Erro ao obter localização:", error);
          this.showError(
            "Acesso à localização negado",
            "Por favor, habilite os serviços de localização para ver os dados da lua",
          );
        },
      );
    } else {
      this.showError(
        "Acesso à localização não suportado",
        "Seu navegador não suporta geolocalização",
      );
    }
  }

  showError(title, description) {
    if (this.hasLoadingTextTarget) {
      this.loadingTextTarget.textContent = title;
    }

    if (this.hasLoadingSubtextTarget) {
      this.loadingSubtextTarget.textContent = description;
    }
  }
}