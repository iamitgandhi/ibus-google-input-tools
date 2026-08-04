# -*- coding: utf-8 -*-
# vim:et sts=4 sw=4
#
# Google Input Tools Transliterator for ibus-typing-booster
# Provides local-first transliteration with Google API fallback.
#
# Architecture:
#   1. User dictionary lookup (instant, 0ms)  - 308K+ words
#   2. API cache lookup (instant, 0ms)         - previously fetched results
#   3. Google API call (200-800ms)             - only for unknown words
#   4. Results cached persistently for future use
#
# Copyright 2026 Google Input Tools for Linux
# License: GPL-2.0-or-later

import json
import os
import threading
import time
import unicodedata
from typing import Dict, List, Optional, Tuple

try:
    import urllib.request
    import urllib.parse
except ImportError:
    urllib = None  # type: ignore

# Google Input Tools REST API endpoint
_GOOGLE_API_URL = (
    "https://inputtools.google.com/request"
    "?text={text}&itc=hi-t-i0-und&num=8&cp=0&cs=1"
    "&ie=utf-8&oe=utf-8"
)

_USER_AGENT = 'Mozilla/5.0 (X11; Linux x86_64) Gecko/20100101'

# Paths
_USER_DICT_PATH = os.path.expanduser(
    '~/.config/ibus-google-input-tools/user_dict.json')
_API_CACHE_PATH = os.path.expanduser(
    '~/.config/ibus-google-input-tools/api_cache.json')

# Cache limits
_LRU_MAX_SIZE = 2000       # In-memory LRU cache entries
_API_CACHE_MAX_SIZE = 50000  # Persistent API cache entries
_API_TIMEOUT = 1.0          # seconds


class GoogleTransliterator:
    """Local-first Hindi transliterator with Google API fallback.

    Usage:
        t = GoogleTransliterator()
        results = t.transliterate('namaste')
        # Returns: ['नमस्ते', ...]
    """

    def __init__(self):
        # User dictionary (loaded from user_dict.json)
        self._user_dict = {}
        self._user_dict_mtime = 0.0
        self._user_dict_lock = threading.Lock()

        # API response cache (persistent)
        self._api_cache = {}
        self._api_cache_mtime = 0.0
        self._api_cache_dirty = False
        self._api_cache_lock = threading.Lock()

        # In-memory LRU cache (volatile, for speed)
        self._lru_cache = {}
        self._lru_order = []
        self._lru_lock = threading.Lock()

        # Load persistent caches on init
        self._load_user_dict()
        self._load_api_cache()

    # -- Public API --

    def transliterate(self, latin_text):
        """Get Hindi transliterations for Latin input.
        Returns a list of Hindi candidates (best first), or empty list.
        """
        if not latin_text or not latin_text.strip():
            return []

        key = latin_text.strip().lower()

        # 1. Check in-memory LRU cache (fastest)
        with self._lru_lock:
            if key in self._lru_cache:
                if key in self._lru_order:
                    self._lru_order.remove(key)
                self._lru_order.append(key)
                return self._lru_cache[key][:]

        # 2. Check user dictionary (instant, local)
        user_results = self._lookup_user_dict(key)

        # 3. Check API cache (instant, local)
        api_cached = self._lookup_api_cache(key)

        if user_results or api_cached:
            merged = self._merge_results(user_results, api_cached)
            self._lru_put(key, merged)
            return merged

        # 4. No local results - call Google API (blocking)
        api_results = self._call_google_api(key)

        if api_results:
            merged = self._merge_results(user_results, api_results)
            self._api_cache_put(key, api_results)
            self._lru_put(key, merged)
            return merged

        return user_results if user_results else []

    def transliterate_local_only(self, latin_text):
        """Get transliterations from local sources only (no API call).
        Use this for instant suggestions during fast typing.
        """
        if not latin_text or not latin_text.strip():
            return []

        key = latin_text.strip().lower()

        with self._lru_lock:
            if key in self._lru_cache:
                if key in self._lru_order:
                    self._lru_order.remove(key)
                self._lru_order.append(key)
                return self._lru_cache[key][:]

        user_results = self._lookup_user_dict(key)
        api_cached = self._lookup_api_cache(key)

        if user_results or api_cached:
            merged = self._merge_results(user_results, api_cached)
            self._lru_put(key, merged)
            return merged

        return []

    def transliterate_async(self, latin_text):
        """Trigger an async Google API lookup and cache the result."""
        if not latin_text or not latin_text.strip():
            return

        key = latin_text.strip().lower()

        with self._lru_lock:
            if key in self._lru_cache:
                return
        if self._lookup_api_cache(key):
            return

        thread = threading.Thread(
            target=self._async_api_fetch, args=(key,), daemon=True)
        thread.start()

    # -- Private: User Dictionary --

    def _load_user_dict(self):
        try:
            if not os.path.exists(_USER_DICT_PATH):
                return
            mtime = os.path.getmtime(_USER_DICT_PATH)
            if mtime == self._user_dict_mtime:
                return
            with self._user_dict_lock:
                with open(_USER_DICT_PATH, 'r', encoding='utf-8') as f:
                    self._user_dict = json.load(f)
                self._user_dict_mtime = mtime
        except Exception:
            pass

    def _lookup_user_dict(self, key):
        try:
            if os.path.exists(_USER_DICT_PATH):
                mtime = os.path.getmtime(_USER_DICT_PATH)
                if mtime != self._user_dict_mtime:
                    self._load_user_dict()
        except Exception:
            pass

        with self._user_dict_lock:
            entries = self._user_dict.get(key, [])
            if entries:
                sorted_entries = sorted(
                    entries, key=lambda x: x.get('weight', 0), reverse=True)
                return [e['target'] for e in sorted_entries]
        return []

    # -- Private: API Cache --

    def _load_api_cache(self):
        try:
            if not os.path.exists(_API_CACHE_PATH):
                return
            with self._api_cache_lock:
                with open(_API_CACHE_PATH, 'r', encoding='utf-8') as f:
                    self._api_cache = json.load(f)
                self._api_cache_mtime = os.path.getmtime(_API_CACHE_PATH)
        except Exception:
            self._api_cache = {}

    def _save_api_cache(self):
        try:
            with self._api_cache_lock:
                if not self._api_cache_dirty:
                    return
                if len(self._api_cache) > _API_CACHE_MAX_SIZE:
                    keys = list(self._api_cache.keys())
                    for k in keys[:len(keys) - _API_CACHE_MAX_SIZE]:
                        del self._api_cache[k]
                os.makedirs(os.path.dirname(_API_CACHE_PATH), exist_ok=True)
                with open(_API_CACHE_PATH, 'w', encoding='utf-8') as f:
                    json.dump(self._api_cache, f, ensure_ascii=False)
                self._api_cache_dirty = False
        except Exception:
            pass

    def _lookup_api_cache(self, key):
        with self._api_cache_lock:
            result = self._api_cache.get(key, [])
            return result[:] if result else []

    def _api_cache_put(self, key, results):
        with self._api_cache_lock:
            self._api_cache[key] = results
            self._api_cache_dirty = True
        thread = threading.Thread(
            target=self._save_api_cache, daemon=True)
        thread.start()

    # -- Private: LRU Cache --

    def _lru_put(self, key, results):
        with self._lru_lock:
            if key in self._lru_cache:
                self._lru_order.remove(key)
            elif len(self._lru_cache) >= _LRU_MAX_SIZE:
                oldest = self._lru_order.pop(0)
                del self._lru_cache[oldest]
            self._lru_cache[key] = results[:]
            self._lru_order.append(key)

    # -- Private: Google API --

    def _call_google_api(self, latin_text):
        if urllib is None:
            return []
        try:
            url = _GOOGLE_API_URL.format(
                text=urllib.parse.quote(latin_text))
            req = urllib.request.Request(url, headers={
                'User-Agent': _USER_AGENT
            })
            with urllib.request.urlopen(req, timeout=_API_TIMEOUT) as resp:
                data = json.loads(resp.read().decode('utf-8'))
                if (data[0] == 'SUCCESS'
                        and len(data[1]) > 0
                        and len(data[1][0]) > 1):
                    return list(data[1][0][1])
        except Exception:
            pass
        return []

    def _async_api_fetch(self, key):
        results = self._call_google_api(key)
        if results:
            self._api_cache_put(key, results)
            user_results = self._lookup_user_dict(key)
            merged = self._merge_results(user_results, results)
            self._lru_put(key, merged)

    # -- Private: Merge Logic --

    @staticmethod
    def _merge_results(user_results, api_results):
        if not user_results:
            return api_results
        if not api_results:
            return user_results

        merged = list(user_results)
        seen = set(user_results)
        for r in api_results:
            if r not in seen:
                merged.append(r)
                seen.add(r)
        return merged


# Module-level singleton
_instance = None
_instance_lock = threading.Lock()


def get_transliterator():
    """Get the singleton GoogleTransliterator instance."""
    global _instance
    if _instance is None:
        with _instance_lock:
            if _instance is None:
                _instance = GoogleTransliterator()
    return _instance
