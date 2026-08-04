#!/usr/bin/env python3
"""Remove old Google API patch from hunspell_suggest.py and
   inject new patch into hunspell_table.py using raw Latin input."""

import re
import sys
import os
import shutil

ENGINE_DIR = '/usr/share/ibus-typing-booster/engine'
HS_FILE = os.path.join(ENGINE_DIR, 'hunspell_suggest.py')
HT_FILE = os.path.join(ENGINE_DIR, 'hunspell_table.py')
GT_SRC = os.path.join(os.path.dirname(os.path.abspath(__file__)), 'google_transliterate.py')
GT_DST = os.path.join(ENGINE_DIR, 'google_transliterate.py')


def remove_old_hunspell_patch():
    """Remove the old broken Google API patch from hunspell_suggest.py."""
    print("[1/3] Removing old patch from hunspell_suggest.py ...")
    
    with open(HS_FILE, 'r', encoding='utf-8') as f:
        content = f.read()
    
    # Check if old patch exists
    if 'Google Input Tools API Integration' not in content:
        print("  → No old patch found, skipping.")
        return
    
    # Remove the entire block between markers
    # The old patch starts with the marker comment and ends before "suggested_words"
    OLD_BLOCK_START = """
        # ── Google Input Tools API Integration (GIT patch) ──────────"""
    OLD_BLOCK_END = """        # ── End Google Input Tools API Integration ──────────────────

        suggested_words"""
    
    if OLD_BLOCK_START in content and OLD_BLOCK_END in content:
        content = content.replace(
            content[content.index(OLD_BLOCK_START):content.index(OLD_BLOCK_END) + len(OLD_BLOCK_END)],
            "\n        suggested_words"
        )
    else:
        # Fallback: use regex
        content = re.sub(
            r'\n\s*# ── Google Input Tools API Integration.*?# ── End Google Input Tools API Integration[^\n]*\n',
            '\n',
            content,
            flags=re.DOTALL
        )
    
    with open(HS_FILE, 'w', encoding='utf-8') as f:
        f.write(content)
    print("  ✓ Old patch removed from hunspell_suggest.py")


def install_google_transliterate():
    """Copy google_transliterate.py to engine directory."""
    print("[2/3] Installing google_transliterate.py ...")
    
    if os.path.exists(GT_SRC):
        shutil.copy2(GT_SRC, GT_DST)
        os.chmod(GT_DST, 0o644)
        print(f"  ✓ Installed {GT_DST}")
    else:
        print(f"  ✗ Source not found: {GT_SRC}")
        sys.exit(1)


def patch_hunspell_table():
    """Inject Google transliteration into _update_candidates() using raw Latin input."""
    print("[3/3] Patching hunspell_table.py ...")
    
    with open(HT_FILE, 'r', encoding='utf-8') as f:
        content = f.read()
    
    # Check if already patched
    if 'google_transliterate' in content:
        print("  → Already patched, skipping.")
        return
    
    # Find the injection point: right before "phrase_candidates = itb_util.best_candidates(phrase_frequencies)"
    # in _update_candidates method. We need to find the one that's inside the
    # "if self._word_predictions or self._temporary_word_predictions:" block
    
    INJECTION_MARKER = """            phrase_candidates = itb_util.best_candidates(phrase_frequencies)
        # If the first candidate is exactly the same as the typed string"""
    
    if INJECTION_MARKER not in content:
        print("  ✗ Could not find injection marker in hunspell_table.py")
        print("    Looking for alternative marker...")
        # Try simpler marker
        INJECTION_MARKER = "            phrase_candidates = itb_util.best_candidates(phrase_frequencies)\n"
        if INJECTION_MARKER not in content:
            print("  ✗ FAILED: Could not find injection point")
            sys.exit(1)
    
    INJECTION_CODE = """            # ── Google Input Tools Integration (v3 — correct hook point) ──
            # Uses raw Latin _typed_string (NOT Devanagari) for Google API
            try:
                from google_transliterate import get_transliterator as _git_get
                _git_raw_latin = ''.join(self._typed_string)
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

"""
    
    content = content.replace(
        INJECTION_MARKER,
        INJECTION_CODE + INJECTION_MARKER,
        1  # Replace only first occurrence
    )
    
    with open(HT_FILE, 'w', encoding='utf-8') as f:
        f.write(content)
    print("  ✓ hunspell_table.py patched with Google transliteration")


if __name__ == '__main__':
    print("=" * 60)
    print("Google Input Tools v3 — Architectural Fix")
    print("=" * 60)
    print()
    
    remove_old_hunspell_patch()
    install_google_transliterate()
    patch_hunspell_table()
    
    # Clear bytecache
    import glob
    for f in glob.glob(os.path.join(ENGINE_DIR, '__pycache__', '*.pyc')):
        os.remove(f)
    print()
    print("✓ All patches applied successfully!")
    print("  Restart IBus: ibus restart")
