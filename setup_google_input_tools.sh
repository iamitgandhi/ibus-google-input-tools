#!/bin/bash
# ============================================================================
# Google Input Tools for Ubuntu Linux — Master Setup Script
# ============================================================================
# This script configures ibus-typing-booster with:
# - Live Google Input Tools transliteration API for Hindi
# - User dictionary (gg.dic) promotion to Candidate #1
# - Zero-delay candidate popup with auto-highlight
# - GNOME UI: हि symbol, हिन्दी (इंडिया) label
# ============================================================================
set -e

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

log_ok()   { echo -e "${GREEN}✅ $1${NC}"; }
log_warn() { echo -e "${YELLOW}⚠️  $1${NC}"; }
log_err()  { echo -e "${RED}❌ $1${NC}"; }
log_info() { echo -e "   $1"; }

echo "============================================================"
echo " Google Input Tools for Ubuntu Linux — Setup"
echo "============================================================"
echo ""

# ── Step 1: Check/Install System Packages ──────────────────────
echo "── Step 1: System Packages ──"
PKGS="ibus ibus-m17n m17n-db ibus-typing-booster hunspell-hi"
MISSING=""
for pkg in $PKGS; do
    if ! dpkg -l "$pkg" 2>/dev/null | grep -q "^ii"; then
        MISSING="$MISSING $pkg"
    fi
done

if [ -n "$MISSING" ]; then
    log_warn "Installing missing packages:$MISSING"
    sudo apt update -qq && sudo apt install -y $MISSING
else
    log_ok "All system packages installed"
fi

# ── Step 2: Set IBus Environment Variables ─────────────────────
echo ""
echo "── Step 2: IBus Environment Variables ──"
for rc_file in "$HOME/.profile" "$HOME/.bashrc"; do
    if ! grep -q "GTK_IM_MODULE=ibus" "$rc_file" 2>/dev/null; then
        cat >> "$rc_file" << 'IBUSENV'

# Force IBus input method module for GTK, Qt, and X11
export GTK_IM_MODULE=ibus
export QT_IM_MODULE=ibus
export XMODIFIERS=@im=ibus
IBUSENV
        log_ok "Added IBus env vars to $rc_file"
    else
        log_ok "IBus env vars already in $rc_file"
    fi
done

# ── Step 3: Install m17n Scheme File ───────────────────────────
echo ""
echo "── Step 3: m17n Input Method Scheme ──"
M17N_SRC="$HOME/.m17n.d/hi-git-itrans.mim"
M17N_SYS="/usr/share/m17n/hi-git-itrans.mim"

if [ -f "$M17N_SRC" ]; then
    log_ok "hi-git-itrans.mim present at ~/.m17n.d/ ($(wc -l < "$M17N_SRC") lines)"
    if [ ! -f "$M17N_SYS" ]; then
        sudo cp "$M17N_SRC" "$M17N_SYS" 2>/dev/null && \
            log_ok "Copied to system m17n path" || \
            log_warn "Could not copy to system path (non-critical)"
    fi
else
    log_warn "hi-git-itrans.mim not found at ~/.m17n.d/"
    log_info "If you have the file, copy it to: ~/.m17n.d/hi-git-itrans.mim"
fi

# ── Step 4: Backup & Patch hunspell_suggest.py ─────────────────
echo ""
echo "── Step 4: Patch hunspell_suggest.py (Google API) ──"
HS_FILE="/usr/share/ibus-typing-booster/engine/hunspell_suggest.py"

if grep -q "Google Input Tools API Integration" "$HS_FILE" 2>/dev/null; then
    log_ok "hunspell_suggest.py already patched"
else
    if [ ! -f "${HS_FILE}.bak" ]; then
        sudo cp "$HS_FILE" "${HS_FILE}.bak"
        log_ok "Backup created: ${HS_FILE}.bak"
    fi

    sudo python3 - "$HS_FILE" << 'PYEOF'
import sys
TARGET = sys.argv[1]
with open(TARGET, "r", encoding="utf-8") as f:
    content = f.read()
MARKER = """        # make sure input_phrase is in the internal normalization form (NFD):
        input_phrase = unicodedata.normalize(
            itb_util.NORMALIZATION_FORM_INTERNAL, input_phrase)

        suggested_words: Dict[str, Dict[str, int]] = {}"""
REPLACEMENT = """        # make sure input_phrase is in the internal normalization form (NFD):
        input_phrase = unicodedata.normalize(
            itb_util.NORMALIZATION_FORM_INTERNAL, input_phrase)

        # ── Google Input Tools API Integration (GIT patch) ──────────
        try:
            import urllib.request as _git_urlreq
            import urllib.parse as _git_urlparse
            import json as _git_json
            _git_api_url = (
                "https://inputtools.google.com/request"
                "?text=" + _git_urlparse.quote(input_phrase)
                + "&itc=hi-t-i0-und&num=5&cp=0&cs=1"
                + "&ie=utf-8&oe=utf-8"
            )
            _git_req = _git_urlreq.Request(
                _git_api_url,
                headers={'User-Agent': 'Mozilla/5.0'})
            with _git_urlreq.urlopen(_git_req, timeout=0.8) as _git_resp:
                _git_data = _git_json.loads(
                    _git_resp.read().decode('utf-8'))
                if (_git_data[0] == 'SUCCESS'
                        and len(_git_data[1]) > 0):
                    _git_cands = list(_git_data[1][0][1])
                    _git_ud_path = os.path.expanduser(
                        '~/.config/ibus-google-input-tools/user_dict.json')
                    if not hasattr(self, '_git_ud_cache'):
                        self._git_ud_cache = {}
                        self._git_ud_mtime = 0
                    try:
                        if os.path.exists(_git_ud_path):
                            _git_mt = os.path.getmtime(_git_ud_path)
                            if _git_mt != self._git_ud_mtime:
                                with open(_git_ud_path, 'r', encoding='utf-8') as _git_fud:
                                    self._git_ud_cache = _git_json.load(_git_fud)
                                self._git_ud_mtime = _git_mt
                    except Exception:
                        pass
                    _git_key = input_phrase.strip().lower()
                    if _git_key in self._git_ud_cache:
                        _git_uw = [item['target'] for item in self._git_ud_cache[_git_key]]
                        for _git_w in reversed(_git_uw):
                            if _git_w in _git_cands:
                                _git_cands.remove(_git_w)
                            _git_cands.insert(0, _git_w)
                    _git_result = [
                        (unicodedata.normalize(
                            itb_util.NORMALIZATION_FORM_INTERNAL, w), 0)
                        for w in _git_cands
                    ]
                    if _git_result:
                        return _git_result
        except Exception:
            pass
        # ── End Google Input Tools API Integration ──────────────────

        suggested_words: Dict[str, Dict[str, int]] = {}"""
if MARKER not in content:
    print("ERROR: Injection marker not found!"); sys.exit(1)
with open(TARGET, "w", encoding="utf-8") as f:
    f.write(content.replace(MARKER, REPLACEMENT, 1))
print("OK")
PYEOF

    if [ $? -eq 0 ]; then
        log_ok "hunspell_suggest.py patched with Google API integration"
    else
        log_err "Failed to patch hunspell_suggest.py"
    fi
fi

# ── Step 5: Backup & Patch main.py ─────────────────────────────
echo ""
echo "── Step 5: Patch main.py (Hindi UI Labels) ──"
MAIN_FILE="/usr/share/ibus-typing-booster/engine/main.py"

if grep -q "इंडिया" "$MAIN_FILE" 2>/dev/null; then
    log_ok "main.py already patched"
else
    if [ ! -f "${MAIN_FILE}.bak" ]; then
        sudo cp "$MAIN_FILE" "${MAIN_FILE}.bak"
        log_ok "Backup created: ${MAIN_FILE}.bak"
    fi

    sudo python3 - "$MAIN_FILE" << 'PYEOF'
import sys
TARGET = sys.argv[1]
with open(TARGET, "r", encoding="utf-8") as f:
    content = f.read()
content = content.replace("longname = 'Typing Booster'", "longname = 'हिन्दी (इंडिया)'")
content = content.replace("language = 't'", "language = 'hi'")
content = content.replace("symbol = '🚀'", "symbol = 'हि'")
content = content.replace("symbol = '🚀\\uFE0E'", "symbol = 'हि\\uFE0E'")
with open(TARGET, "w", encoding="utf-8") as f:
    f.write(content)
print("OK")
PYEOF

    if [ $? -eq 0 ]; then
        log_ok "main.py patched with Hindi UI labels"
    else
        log_err "Failed to patch main.py"
    fi
fi

# ── Step 6: Apply dconf Settings ───────────────────────────────
echo ""
echo "── Step 6: dconf / GSettings Configuration ──"

PATHS=(
    "/desktop/ibus/engine/typing-booster/"
    "/org/freedesktop/ibus/engine/typing-booster/"
)

for P in "${PATHS[@]}"; do
    dconf write "${P}inputmethod" "'hi-git-itrans'"
    dconf write "${P}dictionary" "'hi_IN'"
    dconf write "${P}inputmode" true
    dconf write "${P}pagesize" 5
    dconf write "${P}shownumberofcandidates" true
    dconf write "${P}autoselectcandidate" 1
    dconf write "${P}candidatesdelaymilliseconds" 0
    dconf write "${P}avoidforwardkeyevent" true
    dconf write "${P}inputmodetruesymbol" "'हि'"
    dconf write "${P}keybindings" "{'cancel': <['Escape']>, 'commit': <['Return', 'KP_Enter']>, 'commit_and_forward_key': <@as []>, 'commit_candidate_1_plus_space': <['1', 'KP_1', 'F1']>, 'commit_candidate_2_plus_space': <['2', 'KP_2', 'F2']>, 'commit_candidate_3_plus_space': <['3', 'KP_3', 'F3']>, 'commit_candidate_4_plus_space': <['4', 'KP_4', 'F4']>, 'commit_candidate_5_plus_space': <['5', 'KP_5', 'F5']>, 'select_next_candidate': <['Tab', 'ISO_Left_Tab', 'Down', 'KP_Down']>, 'select_previous_candidate': <['Shift+Tab', 'Shift+ISO_Left_Tab', 'Up', 'KP_Up']>}"
done

log_ok "dconf settings applied to both paths"

# ── Step 7: GNOME Input Sources ────────────────────────────────
echo ""
echo "── Step 7: GNOME Input Sources ──"
gsettings set org.gnome.desktop.input-sources sources "[('ibus', 'typing-booster'), ('xkb', 'us')]"
gsettings set org.gnome.desktop.input-sources current 0
log_ok "GNOME input sources configured"

# ── Step 8: Rebuild IBus Cache & Restart ───────────────────────
echo ""
echo "── Step 8: IBus Cache & Daemon Restart ──"
sudo rm -rf /usr/share/ibus-typing-booster/engine/__pycache__/
sudo ibus write-cache 2>/dev/null || true
ibus write-cache 2>/dev/null || true
ibus restart 2>/dev/null || ibus-daemon -d -x 2>/dev/null || true
sleep 2
log_ok "IBus cache rebuilt and daemon restarted"

# ── Done ───────────────────────────────────────────────────────
echo ""
echo "============================================================"
echo " ✅ Google Input Tools Setup Complete!"
echo "============================================================"
echo ""
echo " To start using Hindi transliteration:"
echo "   • Press Super+Space to switch input methods"
echo "   • Type in English → see Hindi candidates"
echo "   • Space/Enter commits Candidate #1"
echo ""
echo " To import your custom dictionary:"
echo "   ibus-git-dict --import-dic /path/to/gg.dic"
echo ""
echo " Run verify_setup.sh to test everything."
echo "============================================================"
