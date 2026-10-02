#!/usr/bin/env bash
#
# Lokaler Build fuer Brave Nightly Portable (Portapps).
#
#   ./build-local.sh            Toolchain + Core pruefen, bauen, Icons verifizieren
#   ./build-local.sh setup      Toolchain (Go, JDK 11, Ant) herunterladen/entpacken
#   ./build-local.sh check      nur die vorhandenen Artefakte verifizieren
#
# Alles landet in .tools/ bzw. .portapps/ und ist in .gitignore ausgenommen.

set -euo pipefail

ROOT="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
TOOLS="$ROOT/.tools"
CORE="$ROOT/.portapps"
CORE_REPO="https://github.com/portapps/portapps"
GO_DIR="$TOOLS/go1.27.1"
JDK_DIR="$TOOLS/jdk11"
ANT_DIR="$TOOLS/ant"
LOG="$TOOLS/build-local.log"

GO_URL="https://go.dev/dl/go1.27.1.windows-amd64.zip"
JDK_URL="https://api.adoptium.net/v3/binary/latest/11/ga/windows/x64/jdk/hotspot/normal/eclipse"
ANT_URL="https://dlcdn.apache.org/ant/binaries/apache-ant-1.10.18-bin.zip"

say()  { printf '\033[36m==>\033[0m %s\n' "$*"; }
warn() { printf '\033[33m[! ]\033[0m %s\n' "$*" >&2; }
die()  { printf '\033[31m[xx]\033[0m %s\n' "$*" >&2; exit 1; }

# ---------------------------------------------------------------- Properties
# Liest eine Property aus build.properties und loest Ant-Referenzen auf
# (z. B. papp.id = ${app}-portable -> brave-nightly-portable).
prop() {
  local val ref name repl
  val="$(sed -n "s/^$1[[:space:]]*=[[:space:]]*//p" "$ROOT/build.properties" | head -1)"
  while ref="$(printf '%s' "$val" | grep -o '\${[a-z][a-zA-Z0-9._]*}' | head -1)"; do
    name="${ref#\$\{}"; name="${name%\}}"
    repl="$(sed -n "s/^$name[[:space:]]*=[[:space:]]*//p" "$ROOT/build.properties" | head -1)"
    [ -n "$repl" ] || break
    val="${val//$ref/$repl}"
  done
  printf '%s' "$val"
}
core_version() {
  sed -n 's|.*github.com/portapps/portapps/v3 v\([0-9][^ ]*\).*|\1|p' "$ROOT/go.mod" | head -1
}

# ---------------------------------------------------------------- Toolchain
setup_toolchain() {
  mkdir -p "$TOOLS/dl"
  if [ ! -f "$GO_DIR/bin/go.exe" ]; then
    say "lade Go ...";      curl -fsSL -o "$TOOLS/dl/go.zip"  "$GO_URL"
    say "entpacke Go ...";  unzip -q "$TOOLS/dl/go.zip" -d "$TOOLS" && mv "$TOOLS/go" "$GO_DIR"
  fi
  if [ ! -f "$JDK_DIR/bin/java.exe" ]; then
    say "lade Temurin JDK 11 ..."; curl -fsSL -o "$TOOLS/dl/jdk.zip" "$JDK_URL"
    say "entpacke JDK ..."; unzip -q "$TOOLS/dl/jdk.zip" -d "$TOOLS"
    mv "$(find "$TOOLS" -maxdepth 1 -type d -name 'jdk-*' | head -1)" "$JDK_DIR"
  fi
  if [ ! -f "$ANT_DIR/bin/ant" ]; then
    say "lade Apache Ant ..."; curl -fsSL -o "$TOOLS/dl/ant.zip" "$ANT_URL"
    say "entpacke Ant ..."; unzip -q "$TOOLS/dl/ant.zip" -d "$TOOLS"
    mv "$TOOLS/apache-ant-1.10.18" "$ANT_DIR"
  fi
  rm -rf "$TOOLS/dl"
  say "Toolchain bereit"
}

export_toolchain() {
  [ -f "$GO_DIR/bin/go.exe" ]  || die "Go fehlt: $GO_DIR  ->  ./build-local.sh setup"
  [ -f "$JDK_DIR/bin/java.exe" ] || die "JDK 11 fehlt: $JDK_DIR  ->  ./build-local.sh setup"
  [ -d "$ANT_DIR/bin" ] || die "Ant fehlt: $ANT_DIR  ->  ./build-local.sh setup"
  export JAVA_HOME="$JDK_DIR"
  export ANT_HOME="$ANT_DIR"
  export GOTOOLCHAIN=local
  export PATH="$JDK_DIR/bin:$ANT_DIR/bin:$GO_DIR/bin:$PATH"
}

# ---------------------------------------------------------------- Portapps-Core
ensure_core() {
  local want have
  want="$(core_version)"
  [ -n "$want" ] || die "Portapps-Version nicht in go.mod gefunden"
  if [ -d "$CORE/.git" ]; then
    have="$(git -C "$CORE" describe --tags 2>/dev/null || echo unbekannt)"
    if [ "$have" = "v$want" ]; then
      say "Core v$want bereits vorhanden"
      return
    fi
    warn "Core ist $have, go.mod verlangt v$want -> wechsle"
    git -C "$CORE" fetch --quiet --tags
    git -C "$CORE" checkout --quiet "v$want"
  else
    say "klone Portapps-Core v$want ..."
    git clone --quiet --depth 1 --branch "v$want" "$CORE_REPO" "$CORE"
  fi
}

# ---------------------------------------------------------------- Icon-Check
verify() {
  command -v python >/dev/null 2>&1 || { warn "python fehlt - Icon-Pruefung uebersprungen"; return 0; }
  local app version release papp
  app="$(prop app)"; version="$(prop app.version)"; release="$(prop app.release)"; papp="$(prop papp.id)"
  local launcher="$ROOT/bin/build/${papp}.exe"
  local setup="$ROOT/bin/release/${papp}-win64-${version}-${release}-setup.exe"

  say "Artefakte"
  ls -lh "$ROOT/bin/release" 2>/dev/null | tail -n +2 | awk '{printf "     %-6s %s\n", $5, $9}' \
    || die "keine Artefakte in bin/release - erst bauen"

  python - "$ROOT/res/papp.ico" "$launcher" "$setup" <<'PY' || die "Icon-Pruefung fehlgeschlagen"
import hashlib, struct, sys


def rva2off(segs, rva):
    for vaddr, vsize, raddr, rsize in segs:
        if vaddr <= rva < vaddr + max(vsize, rsize):
            return raddr + (rva - vaddr)
    return None


def image_hashes(path):
    """Alle Bilder der Icon-Gruppe(n) einer PE-Datei als {groesse: md5}."""
    d = open(path, "rb").read()
    e, = struct.unpack_from("<I", d, 0x3C)
    if d[e:e + 4] != b"PE\0\0":
        return {}
    coff = e + 4
    nsec, = struct.unpack_from("<H", d, coff + 2)
    szopt, = struct.unpack_from("<H", d, coff + 16)
    opt = coff + 20
    magic, = struct.unpack_from("<H", d, opt)
    res_rva, = struct.unpack_from("<I", d, opt + (112 if magic == 0x20B else 96) + 16)
    segs = []
    for i in range(nsec):
        o = opt + szopt + i * 40
        vs, va, rs, ra = struct.unpack_from("<IIII", d, o + 8)
        segs.append((va, vs, ra, rs))
    base = rva2off(segs, res_rva)
    if base is None:
        return {}

    def entries(off):
        nn, ni = struct.unpack_from("<HH", d, off + 12)
        return [struct.unpack_from("<II", d, off + 16 + i * 8) for i in range(nn + ni)]

    def key_of(k):
        if not k & 0x80000000:
            return k
        off = base + (k & 0x7FFFFFFF)
        ln, = struct.unpack_from("<H", d, off)
        return d[off + 2:off + 2 + ln * 2].decode("utf-16-le")

    def leaf(off):
        _, data = entries(off)[0]
        drva, size, _, _ = struct.unpack_from("<IIII", d, base + data)
        start = rva2off(segs, drva)
        return d[start:start + size] if start is not None else b""

    icons = {}
    for name, data in entries(base):
        if name == 3:                                    # RT_ICON
            for iid, sub in entries(base + (data & 0x7FFFFFFF)):
                icons[key_of(iid)] = leaf(base + (sub & 0x7FFFFFFF))
    hashes = {}
    for name, data in entries(base):
        if name != 14:                                   # RT_GROUP_ICON
            continue
        for _gid, sub in entries(base + (data & 0x7FFFFFFF)):
            grp = leaf(base + (sub & 0x7FFFFFFF))
            _, _, count = struct.unpack_from("<HHH", grp, 0)
            for i in range(count):
                w, _h, _c, _r, _p, _b, _size, rid = struct.unpack_from("<BBBBHHIH", grp, 6 + i * 14)
                blob = icons.get(key_of(rid), b"")
                if blob:
                    hashes[w or 256] = hashlib.md5(blob).hexdigest()
    return hashes


ref_path, *targets = sys.argv[1:]
ref = image_hashes_of_ico = None
d = open(ref_path, "rb").read()
_, _, cnt = struct.unpack_from("<HHH", d, 0)
for i in range(cnt):
    w, h, _c, _r, _p, _b, size, off = struct.unpack_from("<BBBBHHII", d, 6 + i * 16)
    if (w or 256) == 256:
        ref = hashlib.md5(d[off:off + size]).hexdigest()
        break
if ref is None:
    sys.exit("res/papp.ico hat kein 256px-Bild")

print("     Referenz res/papp.ico: %s" % ref[:12])
rc = 0
for t in targets:
    if not t.endswith(".exe"):
        continue
    import os
    if not os.path.exists(t):
        print("     %-22s FEHLT" % os.path.basename(t))
        rc = 1
        continue
    got = image_hashes(t).get(256)
    ok = got == ref
    rc |= 0 if ok else 1
    print("     %-22s %s  %s" % (os.path.basename(t), (got or "?")[:12],
                                "OK" if ok else "ABWEICHEND"))
sys.exit(rc)
PY
}

# ---------------------------------------------------------------- Aufruf
case "${1:-build}" in
  setup)
    setup_toolchain
    ;;
  check)
    verify
    ;;
  build)
    setup_toolchain
    export_toolchain
    ensure_core
    say "Versionen: go=$("$GO_DIR/bin/go.exe" version | awk '{print $3}') ant=$("$ANT_DIR/bin/ant" -version 2>/dev/null | sed -n 's/.*version \([0-9.]*\).*/\1/p' | head -1)"
    say "baue Brave Nightly $(prop app.version)-$(prop app.release) (Log: ${LOG#$ROOT/})"
    cd "$ROOT"
    ant release -Dcore.dir=./.portapps -Ddebug=true 2>&1 | tee "$LOG"
    echo
    verify
    say "fertig - Artefakte in bin/release"
    ;;
  *)
    sed -n '2,12p' "${BASH_SOURCE[0]}" | sed 's/^# \{0,1\}//'
    exit 1
    ;;
esac
