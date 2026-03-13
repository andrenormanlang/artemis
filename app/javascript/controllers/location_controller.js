import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  connect() {
    this.requestLocation();
  }

  requestLocation() {
    if (navigator.geolocation) {
      navigator.geolocation.getCurrentPosition(
        (position) => {
          const lat = position.coords.latitude;
          const lng = position.coords.longitude;
          
          // Redireciona para a mesma página com os parâmetros
          window.location.href = `?lat=${lat}&lng=${lng}`;
        },
        (error) => {
          console.error("Erro ao obter localização:", error);
          // Tratar erro - talvez redirecionar sem localização?
          window.location.href = "?lat=0&lng=0"; // valor padrão
        }
      );
    } else {
      window.location.href = "?lat=0&lng=0"; // geolocalização não suportada
    }
  }
}