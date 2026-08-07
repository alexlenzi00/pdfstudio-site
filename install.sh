#!/usr/bin/env bash
# Pennino — installazione su Linux in una riga.
#
#   curl -fsSL https://alexlenzi00.github.io/pennino-site/install.sh | bash
#
# Cosa fa, in ordine: scarica l'ultima versione da GitHub, ne verifica
# l'impronta SHA-256, la estrae e lancia l'installazione per l'utente
# corrente (menu applicazioni, icona, comando `pennino`, file .pennino
# associati). NIENTE sudo: si installa sotto ~/.local.
#
# Su Debian/Ubuntu, se mancano le librerie di sistema che servono a Qt,
# lo script se ne accorge e lo dice: quelle non puo' installarle da solo,
# perche' sono pacchetti di sistema e questa installazione NON usa sudo.
# In quel caso la strada piu' comoda e' il pacchetto .deb, che le tira
# dentro da se':
#   curl -fsSL .../install.sh | bash -s -- --deb     (chiede la password)
#
# Opzioni, quando lo si esegue come file invece che da pipe:
#   ./install.sh --prefix DIR    installa altrove (default ~/.local)
#   ./install.sh --version X.Y.Z una versione precisa
#   ./install.sh --deb           installa il .deb con apt (serve sudo)
#   ./install.sh --utente        forza l'installazione in ~/.local
#   ./install.sh --keep          non cancella l'archivio scaricato
#
# Per disinstallare:  ~/.local/opt/pennino/uninstall.sh
set -euo pipefail

REPO="alexlenzi00/pennino-site"
SITO="https://alexlenzi00.github.io/pennino-site"
NOME="Pennino-linux.tar.gz"
PREFIX="${HOME}/.local"
VERSIONE=""
KEEP=0
MODO="auto"          # auto | utente | deb

while [ $# -gt 0 ]; do
    case "$1" in
        --prefix)  PREFIX="$2"; shift 2 ;;
        --version) VERSIONE="$2"; shift 2 ;;
        --keep)    KEEP=1; shift ;;
        --deb)     MODO="deb"; shift ;;
        --utente)  MODO="utente"; shift ;;
        --help|-h) sed -n '2,22p' "$0" | sed 's/^# \{0,1\}//'; exit 0 ;;
        *) echo "opzione sconosciuta: $1" >&2; exit 2 ;;
    esac
done

rosso() { printf '\033[31m%s\033[0m\n' "$*" >&2; }
verde() { printf '\033[32m%s\033[0m\n' "$*"; }
info()  { printf '%s\n' "$*"; }

# Uno script lanciato con `curl | bash` che muore in silenzio e' la cosa
# peggiore: l'utente non sa se ha installato o no. Con `set -e` basta un
# comando che ritorna 1 (un grep senza risultati) per uscire senza una
# parola: qui invece si dice sempre dove ci si e' fermati.
trap 'rosso "Installazione interrotta alla riga $LINENO. Niente e'\'' stato modificato di permanente."' ERR

# --- 1. serve qualcosa per scaricare, e i soliti attrezzi ------------------
if command -v curl >/dev/null 2>&1; then
    SCARICA() { curl -fsSL "$1" -o "$2"; }
    LEGGI()   { curl -fsSL "$1"; }
elif command -v wget >/dev/null 2>&1; then
    SCARICA() { wget -qO "$2" "$1"; }
    LEGGI()   { wget -qO- "$1"; }
else
    rosso "Serve curl o wget per scaricare Pennino."
    exit 1
fi

for prog in tar sha256sum; do
    command -v "$prog" >/dev/null 2>&1 || {
        rosso "Manca '$prog': installalo e riprova."; exit 1; }
done

# --- 2. architettura: i pacchetti sono solo x86-64 -------------------------
ARCH="$(uname -m)"
if [ "$ARCH" != "x86_64" ] && [ "$ARCH" != "amd64" ]; then
    rosso "Architettura $ARCH non supportata: Pennino per Linux e' x86-64."
    rosso "Sorgenti e istruzioni: https://alexlenzi00.github.io/pennino-site/"
    exit 1
fi

# --- 3. da dove scaricare -------------------------------------------------
if [ -n "$VERSIONE" ]; then
    BASE="https://github.com/${REPO}/releases/download/v${VERSIONE}"
else
    BASE="https://github.com/${REPO}/releases/latest/download"
fi

TMP="$(mktemp -d)"
# la cartella temporanea sparisce sempre, anche se qualcosa va storto
trap '[ "$KEEP" = 1 ] || rm -rf "$TMP"' EXIT

# --- 3-bis. le librerie di Qt: chi le installa? ----------------------------
# Qt le carica con dlopen, quindi non compaiono in `ldd` e la loro assenza
# si manifesta solo all'avvio, con un "ImportError: libGL.so.1" che non
# aiuta nessuno. Il .deb le dichiara e apt le risolve; l'installazione
# per-utente non puo' (sono pacchetti di sistema e qui non si usa sudo).
mancanti=""
for lib in libGL.so.1 libEGL.so.1 libxkbcommon-x11.so.0 libfontconfig.so.1; do
    ldconfig -p 2>/dev/null | grep -q "$lib" || mancanti="${mancanti} ${lib}"
done

if [ "$MODO" = auto ] && [ -n "$mancanti" ] && command -v apt-get >/dev/null 2>&1; then
    info ""
    info "Mancano alcune librerie di sistema che servono a Qt:${mancanti}"
    info "Su Debian/Ubuntu le installa da se' il pacchetto .deb."
    # Da `curl | bash` lo stdin e' la pipe, non la tastiera: per chiedere
    # davvero all'utente serve il terminale, /dev/tty. Se non c'e'
    # (script non interattivo, CI) non si indovina: si spiega e si va
    # avanti con l'installazione per-utente.
    # ⚠️ `[ -e /dev/tty ]` non basta: il file esiste anche dove non si puo'
    # aprire (container senza tty, cron), e la lettura fallisce con un
    # errore brutto dopo aver gia' stampato la domanda. Si prova ad
    # aprirlo davvero, in silenzio.
    if (: < /dev/tty) 2>/dev/null && command -v sudo >/dev/null 2>&1; then
        printf 'Installo il .deb con apt (serve la tua password)? [S/n] '
        risposta=""
        read -r risposta < /dev/tty || risposta="n"
        case "$risposta" in
            ""|s|S|y|Y) MODO="deb" ;;
            *) MODO="utente" ;;
        esac
    else
        info "Per farlo:  curl -fsSL ${SITO}/install.sh | bash -s -- --deb"
        MODO="utente"
    fi
fi

# --- 3-ter. la strada .deb: apt risolve tutto -------------------------------
if [ "$MODO" = deb ]; then
    command -v apt-get >/dev/null 2>&1 || {
        rosso "--deb funziona solo su Debian/Ubuntu (qui non c'e' apt)."
        exit 1; }
    command -v sudo >/dev/null 2>&1 || {
        rosso "--deb richiede sudo per installare i pacchetti di sistema."
        exit 1; }
    if [ -n "$VERSIONE" ]; then
        DEB="pennino_${VERSIONE}_amd64.deb"
    else
        # il nome contiene la versione: si legge dall'elenco delle impronte
        LEGGI "${BASE}/SHA256SUMS.txt" > "${TMP}/SHA256SUMS.txt" 2>/dev/null || true
        DEB="$(awk '{f=$2; sub(/^\*/,"",f); sub(/\r$/,"",f)
                     if (f ~ /^pennino_.*\.deb$/) {print f; exit}}' \
               "${TMP}/SHA256SUMS.txt" 2>/dev/null)"
    fi
    [ -n "${DEB:-}" ] || { rosso "non trovo il nome del pacchetto .deb"; exit 1; }

    info "Scarico ${DEB}…"
    SCARICA "${BASE}/${DEB}" "${TMP}/${DEB}" || {
        rosso "download fallito: ${BASE}/${DEB}"; exit 1; }

    ATTESA="$(awk -v n="$DEB" '{f=$2; sub(/^\*/,"",f); sub(/\r$/,"",f)
                                if (f==n) {print $1; exit}}' \
              "${TMP}/SHA256SUMS.txt" 2>/dev/null)"
    if [ -n "${ATTESA:-}" ]; then
        VERA="$(sha256sum "${TMP}/${DEB}" | awk '{print $1}')"
        [ "$ATTESA" = "$VERA" ] || {
            rosso "IMPRONTA SBAGLIATA sul .deb: installazione interrotta."
            exit 1; }
        info "Impronta SHA-256 verificata."
    fi

    info "Installo con apt (le dipendenze le risolve lui)…"
    sudo apt-get install -y "${TMP}/${DEB}"
    verde ""
    verde "Pennino installato. Avvialo dal menu applicazioni o con: pennino"
    verde "Per toglierlo:  sudo apt remove pennino"
    exit 0
fi

info "Scarico Pennino…"
SCARICA "${BASE}/${NOME}" "${TMP}/${NOME}" || {
    rosso "Download fallito da ${BASE}/${NOME}"
    exit 1
}

# --- 4. l'impronta: si controlla, non si spera -----------------------------
# SHA256SUMS.txt e' pubblicato accanto ai pacchetti e le stesse impronte
# sono sulla pagina Scarica del sito: se un giorno la release fosse
# manomessa, qui l'installazione si ferma invece di eseguire il file.
if LEGGI "${BASE}/SHA256SUMS.txt" > "${TMP}/SHA256SUMS.txt" 2>/dev/null; then
    # Le righe sono "impronta *nome" (l'asterisco e' la modalita' binaria
    # di sha256sum). Si confronta il NOME esatto, non una sottostringa:
    # con `grep " nome"` non trovava niente e, con set -e, lo script
    # moriva zitto proprio qui. awk esce 0 anche quando non trova nulla.
    ATTESA="$(awk -v n="$NOME" '
        { f = $2; sub(/^\*/, "", f); sub(/\r$/, "", f)
          if (f == n) { print $1; exit } }' "${TMP}/SHA256SUMS.txt")"
    if [ -n "$ATTESA" ]; then
        VERA="$(sha256sum "${TMP}/${NOME}" | awk '{print $1}')"
        if [ "$ATTESA" != "$VERA" ]; then
            rosso "IMPRONTA SBAGLIATA: il file scaricato non e' quello pubblicato."
            rosso "  attesa: $ATTESA"
            rosso "  vera:   $VERA"
            rosso "Installazione interrotta."
            exit 1
        fi
        info "Impronta SHA-256 verificata."
    else
        info "(l'impronta di ${NOME} non e' nell'elenco: salto la verifica)"
    fi
else
    info "(SHA256SUMS.txt non disponibile: salto la verifica)"
fi

# --- 5. estrai e installa --------------------------------------------------
info "Estraggo…"
tar -xzf "${TMP}/${NOME}" -C "${TMP}"

SRC="$(find "${TMP}" -maxdepth 2 -name install.sh -type f | head -1)"
[ -n "$SRC" ] || { rosso "archivio inatteso: manca install.sh"; exit 1; }
SRC="$(dirname "$SRC")"

chmod +x "${SRC}/install.sh"
"${SRC}/install.sh" --prefix "$PREFIX"

# Il resto (menu, icona, comando nel PATH, come disinstallare) lo dice
# gia' l'install.sh dentro l'archivio: ripeterlo qui darebbe due volte le
# stesse istruzioni, con il rischio che un giorno divergano.
verde ""
verde "Pennino ${VERSIONE:-(ultima versione)} installato."
