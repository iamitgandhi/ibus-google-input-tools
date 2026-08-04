#!/bin/bash
# ============================================================================
# Auto re-patch ibus-typing-booster after apt upgrade (v3)
# Location: /usr/local/bin/ibus-git-repatch.sh
# Triggered by: /etc/apt/apt.conf.d/99-ibus-google-input-tools
# ============================================================================

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ENGINE_DIR="/usr/share/ibus-typing-booster/engine"
HS="$ENGINE_DIR/hunspell_suggest.py"
HT="$ENGINE_DIR/hunspell_table.py"
MAIN="$ENGINE_DIR/main.py"
GT_SRC="/home/amit/.gemini/antigravity/scratch/ibus-google-input-tools/google_transliterate.py"
GT_DST="$ENGINE_DIR/google_transliterate.py"
LOG="/var/log/ibus-git-repatch.log"

# Only run if files exist
[ -f "$HT" ] || exit 0

# Check if already patched (v3 marker)
grep -q "google_transliterate" "$HT" 2>/dev/null && exit 0

echo "$(date): ibus-typing-booster updated — re-applying v3 Google Input Tools patches..." >> "$LOG"

# ── Step 1: Install google_transliterate.py ──
if [ -f "$GT_SRC" ]; then
    cp "$GT_SRC" "$GT_DST"
    chmod 644 "$GT_DST"
    echo "  ✓ google_transliterate.py installed" >> "$LOG"
fi

# ── Step 2: Remove old v2 patch from hunspell_suggest.py (if present) ──
if grep -q "Google Input Tools API Integration" "$HS" 2>/dev/null; then
    python3 -c "
import re
with open('$HS', 'r', encoding='utf-8') as f:
    content = f.read()
content = re.sub(
    r'\n\s*# ── Google Input Tools API Integration.*?# ── End Google Input Tools API Integration[^\n]*\n',
    '\n', content, flags=re.DOTALL)
with open('$HS', 'w', encoding='utf-8') as f:
    f.write(content)
print('OK')
"
    echo "  ✓ Old v2 patch removed from hunspell_suggest.py" >> "$LOG"
fi

# ── Step 3: Patch hunspell_table.py with v3 hook ──
if ! grep -q "google_transliterate" "$HT" 2>/dev/null; then
    python3 -c "
with open('$HT', 'r', encoding='utf-8') as f:
    content = f.read()

MARKER = '            phrase_candidates = itb_util.best_candidates(phrase_frequencies)'
INJECTION = '''            # ── Google Input Tools Integration (v3 — correct hook point) ──
            # Uses raw Latin _typed_string (NOT Devanagari) for Google API
            try:
                from google_transliterate import get_transliterator as _git_get
                _git_raw_latin = \\'\\'.join(self._typed_string)
                if _git_raw_latin and _git_raw_latin.isascii():
                    _git_trans = _git_get()
                    # Try local-first (instant: user dict + API cache)
                    _git_results = _git_trans.transliterate_local_only(_git_raw_latin)
                    if not _git_results:
                        # No local match — call Google API (blocking)
                        _git_results = _git_trans.transliterate(_git_raw_latin)
                    if _git_results:
                        # Inject with descending high frequencies so they appear first
                        _git_base_freq = 99.0
                        for _git_i, _git_word in enumerate(_git_results[:8]):
                            _git_freq = _git_base_freq - _git_i
                            if _git_word in phrase_frequencies:
                                phrase_frequencies[_git_word] = max(
                                    phrase_frequencies[_git_word], _git_freq)
                            else:
                                phrase_frequencies[_git_word] = _git_freq
                    else:
                        # Trigger async fetch for next time
                        _git_trans.transliterate_async(_git_raw_latin)
            except Exception:
                pass
            # ── End Google Input Tools Integration ──────────────────────

'''

if MARKER in content and 'google_transliterate' not in content:
    content = content.replace(MARKER, INJECTION + MARKER, 1)
    with open('$HT', 'w', encoding='utf-8') as f:
        f.write(content)
    print('OK: hunspell_table.py patched')
else:
    print('SKIP: marker not found or already patched')
"
    echo "  ✓ hunspell_table.py patched with v3 hook" >> "$LOG"
fi

# ── Step 4: Patch main.py (UI labels) ──
if [ -f "$MAIN" ] && ! grep -q "इंडिया" "$MAIN" 2>/dev/null; then
    python3 -c "
with open('$MAIN', 'r', encoding='utf-8') as f:
    content = f.read()
content = content.replace(\"longname = 'Typing Booster'\", \"longname = 'इंडिया'\")
content = content.replace(\"language = 't'\", \"language = 'hi'\")
content = content.replace(\"symbol = '🚀'\", \"symbol = 'हि'\")
with open('$MAIN', 'w', encoding='utf-8') as f:
    f.write(content)
print('OK')
"
    echo "  ✓ main.py patched" >> "$LOG"
fi

# ── Step 5: Clear bytecache and rebuild IBus cache ──
rm -rf "$ENGINE_DIR/__pycache__/"
ibus write-cache 2>/dev/null || true

echo "$(date): v3 patches re-applied successfully." >> "$LOG"
