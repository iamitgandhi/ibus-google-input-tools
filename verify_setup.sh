#!/bin/bash
# ============================================================================
# Google Input Tools for Ubuntu — Setup Verification
# ============================================================================
set -u

PASS=0
FAIL=0
WARN=0

check_pass() { echo -e "\033[0;32m  ✅ PASS: $1\033[0m"; PASS=$((PASS+1)); }
check_fail() { echo -e "\033[0;31m  ❌ FAIL: $1\033[0m"; FAIL=$((FAIL+1)); }
check_warn() { echo -e "\033[1;33m  ⚠️  WARN: $1\033[0m"; WARN=$((WARN+1)); }

echo "============================================================"
echo " Google Input Tools — Setup Verification"
echo "============================================================"
echo ""

# ── 1. System Packages ─────────────────────────────────────────
echo "── 1. System Packages ──"
for pkg in ibus ibus-m17n m17n-db ibus-typing-booster hunspell-hi; do
    if dpkg -l "$pkg" 2>/dev/null | grep -q "^ii"; then
        check_pass "$pkg installed"
    else
        check_fail "$pkg NOT installed"
    fi
done

# ── 2. IBus Environment Variables ──────────────────────────────
echo ""
echo "── 2. IBus Environment Variables ──"
if grep -q "GTK_IM_MODULE=ibus" ~/.profile 2>/dev/null; then
    check_pass "GTK_IM_MODULE=ibus in ~/.profile"
else
    check_fail "GTK_IM_MODULE not in ~/.profile"
fi

# ── 3. m17n Scheme File ───────────────────────────────────────
echo ""
echo "── 3. m17n Scheme File ──"
if [ -f "$HOME/.m17n.d/hi-git-itrans.mim" ]; then
    LINES=$(wc -l < "$HOME/.m17n.d/hi-git-itrans.mim")
    check_pass "hi-git-itrans.mim present ($LINES lines)"
else
    check_fail "hi-git-itrans.mim NOT found at ~/.m17n.d/"
fi

# ── 4. hunspell_suggest.py Patch ──────────────────────────────
echo ""
echo "── 4. hunspell_suggest.py (Google API Patch) ──"
HS_FILE="/usr/share/ibus-typing-booster/engine/hunspell_suggest.py"
if grep -q "Google Input Tools API Integration" "$HS_FILE" 2>/dev/null; then
    check_pass "Google API patch present in hunspell_suggest.py"
else
    check_fail "Google API patch NOT found in hunspell_suggest.py"
fi
if [ -f "${HS_FILE}.bak" ]; then
    check_pass "Backup exists: hunspell_suggest.py.bak"
else
    check_warn "No backup found for hunspell_suggest.py"
fi

# ── 5. main.py Patch ─────────────────────────────────────────
echo ""
echo "── 5. main.py (Hindi UI Labels) ──"
MAIN_FILE="/usr/share/ibus-typing-booster/engine/main.py"
if grep -q "इंडिया" "$MAIN_FILE" 2>/dev/null; then
    check_pass "Hindi longname 'हिन्दी (इंडिया)' present"
else
    check_fail "Hindi longname NOT found in main.py"
fi
if grep -q "symbol = 'हि'" "$MAIN_FILE" 2>/dev/null; then
    check_pass "Hindi symbol 'हि' present"
else
    check_fail "Hindi symbol NOT found in main.py"
fi

# ── 6. dconf Settings ────────────────────────────────────────
echo ""
echo "── 6. dconf Settings ──"
P="/desktop/ibus/engine/typing-booster/"
IM=$(dconf read "${P}inputmethod" 2>/dev/null)
AS=$(dconf read "${P}autoselectcandidate" 2>/dev/null)
DL=$(dconf read "${P}candidatesdelaymilliseconds" 2>/dev/null)
SY=$(dconf read "${P}inputmodetruesymbol" 2>/dev/null)

if [ "$IM" = "'hi-git-itrans'" ]; then
    check_pass "Input method: hi-git-itrans"
else
    check_fail "Input method is '$IM' (expected 'hi-git-itrans')"
fi
if [ "$AS" = "1" ]; then
    check_pass "Autoselect candidate: 1"
else
    check_fail "Autoselect candidate is '$AS' (expected 1)"
fi
if [ "$DL" = "0" ]; then
    check_pass "Candidate delay: 0ms (zero-lag)"
else
    check_fail "Candidate delay is '$DL' (expected 0)"
fi
if [ "$SY" = "'हि'" ]; then
    check_pass "Top bar symbol: हि"
else
    check_fail "Symbol is '$SY' (expected 'हि')"
fi

# ── 7. GNOME Input Sources ───────────────────────────────────
echo ""
echo "── 7. GNOME Input Sources ──"
SOURCES=$(gsettings get org.gnome.desktop.input-sources sources 2>/dev/null)
if echo "$SOURCES" | grep -q "typing-booster"; then
    check_pass "typing-booster in GNOME input sources"
else
    check_fail "typing-booster NOT in GNOME input sources ($SOURCES)"
fi

# ── 8. typing-booster Process ────────────────────────────────
echo ""
echo "── 8. typing-booster Process ──"
TB_PID=$(pgrep -f "ibus-typing-booster/engine/main.py" 2>/dev/null || true)
if [ -n "$TB_PID" ]; then
    check_pass "typing-booster process running (PID: $TB_PID)"
else
    check_fail "typing-booster process NOT running"
fi

# ── 9. Google API Connectivity ───────────────────────────────
echo ""
echo "── 9. Google Input Tools API Test ──"
API_RESULT=$(python3 -c "
import urllib.request, json
url = 'https://inputtools.google.com/request?text=nyayadhish&itc=hi-t-i0-und&num=5&cp=0&cs=1&ie=utf-8&oe=utf-8'
try:
    r = urllib.request.urlopen(urllib.request.Request(url, headers={'User-Agent':'Mozilla/5.0'}), timeout=3)
    d = json.loads(r.read())
    if d[0] == 'SUCCESS':
        print('|'.join(d[1][0][1]))
    else:
        print('API_ERROR')
except Exception as e:
    print(f'NETWORK_ERROR:{e}')
" 2>/dev/null)

if echo "$API_RESULT" | grep -q "न्यायाधीश"; then
    check_pass "API test: 'nyayadhish' → $API_RESULT"
else
    check_fail "API test failed: $API_RESULT"
fi

# ── 10. User Dictionary ─────────────────────────────────────
echo ""
echo "── 10. User Dictionary ──"
UD_FILE="$HOME/.config/ibus-google-input-tools/user_dict.json"
if [ -f "$UD_FILE" ]; then
    UD_SIZE=$(du -h "$UD_FILE" | cut -f1)
    UD_KEYS=$(python3 -c "import json; d=json.load(open('$UD_FILE')); print(len(d))" 2>/dev/null || echo "?")
    check_pass "User dictionary: $UD_SIZE ($UD_KEYS word keys)"
    
    # Test specific words
    for word in mukhya seva shriman; do
        FOUND=$(python3 -c "
import json
d=json.load(open('$UD_FILE'))
if '$word' in d:
    print(d['$word'][0]['target'])
else:
    print('NOT_FOUND')
" 2>/dev/null)
        if [ "$FOUND" != "NOT_FOUND" ] && [ -n "$FOUND" ]; then
            check_pass "User dict: '$word' → '$FOUND'"
        else
            check_warn "User dict: '$word' not found (import gg.dic if needed)"
        fi
    done
else
    check_warn "User dictionary not found at $UD_FILE"
fi

# ── Summary ──────────────────────────────────────────────────
echo ""
echo "============================================================"
echo " Verification Summary"
echo "============================================================"
echo -e "  \033[0;32m✅ Passed: $PASS\033[0m"
echo -e "  \033[0;31m❌ Failed: $FAIL\033[0m"
echo -e "  \033[1;33m⚠️  Warnings: $WARN\033[0m"
echo ""
if [ $FAIL -eq 0 ]; then
    echo -e " \033[0;32m🎉 ALL CHECKS PASSED! System is ready.\033[0m"
else
    echo -e " \033[0;31m⚠️  $FAIL checks failed. Review the output above.\033[0m"
fi
echo "============================================================"
