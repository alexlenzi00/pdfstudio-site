/* Tema (chiaro/scuro) e menu mobile — condiviso da tutte le pagine. */
(function () {
  var root = document.documentElement;
  function current() {
    return root.getAttribute('data-theme') ||
      (matchMedia('(prefers-color-scheme: dark)').matches ? 'dark' : 'light');
  }
  document.addEventListener('click', function (e) {
    var t = e.target.closest('[data-theme-toggle]');
    if (t) { root.setAttribute('data-theme', current() === 'dark' ? 'light' : 'dark'); }
    var m = e.target.closest('[data-nav-toggle]');
    if (m) {
      var links = document.querySelector('.nav-links');
      if (links) { links.classList.toggle('open'); }
    }
  });
})();
