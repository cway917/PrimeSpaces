// GitHub Pages serves this entry; the authenticated application runs on its private host.
// Keep the destination fixed. Never accept a redirect URL from query parameters.
(function () {
  "use strict";
  var appOrigin = "https://primespaces-private-pilot.charter-one-3074.chatgpt.site";
  var aliases = {spaces:"explore", searchform:"explore", owners:"facility", benefits:"how", home:"explore"};
  var requested = window.location.hash.slice(1);
  var route = aliases[requested] || requested;
  var allowed = /^(explore|bookings|facility|admin|how)$/.test(route) ||
    /^space\/[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$/i.test(route);
  var destination = appOrigin + "/" + (allowed ? "#" + route : "");
  var fallback = document.getElementById("open-marketplace");
  if (fallback) fallback.href = destination;
  window.location.replace(destination);
}());
