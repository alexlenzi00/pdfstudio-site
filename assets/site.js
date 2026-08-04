/* Tema (chiaro/scuro), menu mobile e lingua — condiviso da tutte le pagine. */
(function () {
  var root = document.documentElement;

  /* ---------------------------------------------------------------- tema */
  function temaCorrente() {
    return root.getAttribute('data-theme') ||
      (matchMedia('(prefers-color-scheme: dark)').matches ? 'dark' : 'light');
  }

  /* ------------------------------------------------------------- lingua */
  /* Il testo italiano resta nel documento; la traduzione vive
     nell'attributo data-en dell'elemento. Al cambio si scambia l'innerHTML
     e si mette da parte l'originale in data-it, cosi' si torna indietro
     senza ricaricare e senza perdere niente. Gli elementi senza data-en
     restano in italiano: e' voluto, e le pagine non ancora tradotte lo
     dichiarano con [data-untranslated]. */
  var CHIAVE = 'pennino-lang';

  function linguaSalvata() {
    try { return localStorage.getItem(CHIAVE); } catch (e) { return null; }
  }

  function applicaLingua(l) {
    var elementi = document.querySelectorAll('[data-en]');
    for (var i = 0; i < elementi.length; i++) {
      var el = elementi[i];
      if (!el.hasAttribute('data-it')) {
        el.setAttribute('data-it', el.innerHTML);
      }
      el.innerHTML = el.getAttribute(l === 'en' ? 'data-en' : 'data-it');
    }
    /* testi che non stanno nel contenuto: alt delle immagini e title */
    var alt = document.querySelectorAll('[data-en-alt]');
    for (var j = 0; j < alt.length; j++) {
      var im = alt[j];
      if (!im.hasAttribute('data-it-alt')) {
        im.setAttribute('data-it-alt', im.getAttribute('alt') || '');
      }
      im.setAttribute('alt', im.getAttribute(l === 'en' ? 'data-en-alt'
                                                       : 'data-it-alt'));
    }
    /* schermate: in inglese si mostra la versione con l'app in inglese */
    var img = document.querySelectorAll('[data-en-src]');
    for (var s = 0; s < img.length; s++) {
      var im = img[s];
      if (!im.hasAttribute('data-it-src')) {
        im.setAttribute('data-it-src', im.getAttribute('src'));
      }
      im.setAttribute('src', im.getAttribute(l === 'en' ? 'data-en-src'
                                                        : 'data-it-src'));
    }
    var titolo = document.querySelector('[data-en-title]');
    if (titolo) {
      if (!titolo.hasAttribute('data-it-title')) {
        titolo.setAttribute('data-it-title', document.title);
      }
      document.title = titolo.getAttribute(l === 'en' ? 'data-en-title'
                                                      : 'data-it-title');
    }
    root.setAttribute('lang', l);
    root.setAttribute('data-lang', l);
    var bottoni = document.querySelectorAll('[data-lang-toggle]');
    for (var k = 0; k < bottoni.length; k++) {
      /* il pulsante mostra la lingua verso cui si passa */
      bottoni[k].textContent = l === 'en' ? 'IT' : 'EN';
      bottoni[k].setAttribute('aria-label',
        l === 'en' ? 'Passa all’italiano' : 'Switch to English');
      bottoni[k].setAttribute('title', bottoni[k].getAttribute('aria-label'));
    }
    try { localStorage.setItem(CHIAVE, l); } catch (e) { /* privata: pazienza */ }
  }

  /* All'apertura: lingua scelta in precedenza, altrimenti quella del
     browser se non e' italiano. Chi arriva da un link condiviso in un
     gruppo internazionale trova la pagina gia' nella sua lingua. */
  var iniziale = linguaSalvata();
  if (!iniziale) {
    var nav = (navigator.language || 'it').toLowerCase();
    iniziale = nav.indexOf('it') === 0 ? 'it' : 'en';
  }
  if (document.readyState === 'loading') {
    document.addEventListener('DOMContentLoaded', function () {
      applicaLingua(iniziale);
    });
  } else {
    applicaLingua(iniziale);
  }

  /* ---------------------------------------------------------------- clic */
  document.addEventListener('click', function (e) {
    var t = e.target.closest('[data-theme-toggle]');
    if (t) {
      root.setAttribute('data-theme',
                        temaCorrente() === 'dark' ? 'light' : 'dark');
    }
    var m = e.target.closest('[data-nav-toggle]');
    if (m) {
      var links = document.querySelector('.nav-links');
      if (links) { links.classList.toggle('open'); }
    }
    var l = e.target.closest('[data-lang-toggle]');
    if (l) {
      applicaLingua(root.getAttribute('data-lang') === 'en' ? 'it' : 'en');
    }
  });
})();
