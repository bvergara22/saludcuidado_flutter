// Arranque de Flutter Web, escrito a mano en lugar del que genera Flutter.
//
// El arranque por defecto registra un service worker que guarda la app
// entera en el navegador. Aquí estorba más de lo que ayuda:
//
//   - La app ya funciona sin conexión por su cuenta: las citas y el
//     catálogo se guardan con shared_preferences, que es caché de datos,
//     no de archivos. El service worker no aporta nada a eso.
//   - A cambio, deja versiones viejas pegadas al teléfono. En iOS es
//     especialmente tozudo: sigue sirviendo la copia guardada aunque el
//     servidor ya tenga otra, y no hay forma de que el usuario lo note.
//     Una corrección publicada no llega nunca.
//
// Para una app que se despliega varias veces al día y que alguien va a
// abrir una sola vez desde su móvil, servir siempre la versión actual
// vale más que ahorrar una descarga.

{{flutter_js}}
{{flutter_build_config}}

// Se arranca primero y se limpia después, nunca al revés: si la limpieza
// fallara o se quedara colgada, la app tiene que cargar igual. Quedarse
// con una copia vieja es malo; no arrancar es peor.
_flutter.loader.load();

// Borra el service worker y las cachés que dejaran versiones anteriores.
// No afecta a esta carga -ya está en marcha- sino a la siguiente, que es
// cuando el teléfono dejará de ver la copia vieja.
(function () {
  try {
    if ('serviceWorker' in navigator && navigator.serviceWorker.getRegistrations) {
      navigator.serviceWorker.getRegistrations().then(function (registros) {
        registros.forEach(function (r) { r.unregister(); });
      }).catch(function () {});
    }
    if (window.caches && caches.keys) {
      caches.keys().then(function (claves) {
        claves.forEach(function (c) { caches.delete(c); });
      }).catch(function () {});
    }
  } catch (e) {
    // Navegador sin permiso para tocar esto: no es motivo para romper nada.
  }
})();
