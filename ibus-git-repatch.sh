#!/bin/bash
# ============================================================================
# Auto re-patch ibus-typing-booster after apt upgrade
# Location: /usr/local/bin/ibus-git-repatch.sh
# Triggered by: /etc/apt/apt.conf.d/99-ibus-google-input-tools
# ============================================================================

HS="/usr/share/ibus-typing-booster/engine/hunspell_suggest.py"
MAIN="/usr/share/ibus-typing-booster/engine/main.py"
LOG="/var/log/ibus-git-repatch.log"

# Only run if files exist and are NOT already patched
[ -f "$HS" ] || exit 0
grep -q "Google Input Tools API Integration" "$HS" 2>/dev/null && exit 0

echo "$(date): ibus-typing-booster updated — re-applying Google Input Tools patches..." >> "$LOG"

# Patch hunspell_suggest.py
python3 - "$HS" << 'PYEOF'
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
    print("WARN: marker not found, skipping hunspell patch"); sys.exit(0)
with open(TARGET, "w", encoding="utf-8") as f:
    f.write(content.replace(MARKER, REPLACEMENT, 1))
print("OK: hunspell_suggest.py patched")
PYEOF

# Patch main.py
if [ -f "$MAIN" ] && ! grep -q "इंडिया" "$MAIN" 2>/dev/null; then
    sed -i "s/longname = 'Typing Booster'/longname = 'इंडिया'/g" "$MAIN"
    sed -i "s/language = 't'/language = 'hi'/g" "$MAIN"
    sed -i "s/symbol = '🚀'/symbol = 'हि'/g" "$MAIN"
    sed -i "s/symbol = '🚀\x{FE0E}'/symbol = 'हि\x{FE0E}'/g" "$MAIN"
    echo "OK: main.py patched" >> "$LOG"
fi

# Clear bytecache and rebuild IBus cache
rm -rf /usr/share/ibus-typing-booster/engine/__pycache__/
ibus write-cache 2>/dev/null || true

echo "$(date): Patches re-applied successfully." >> "$LOG"
