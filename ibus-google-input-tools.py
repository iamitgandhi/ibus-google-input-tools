#!/usr/bin/env python3
import sys
import os
import json
import urllib.request
import urllib.parse
import gi

gi.require_version('IBus', '1.0')
from gi.repository import IBus, GLib, GObject

from user_dict_manager import UserDictionaryManager

LOG_FILE = "/tmp/ibus-git.log"

def log_debug(msg):
    try:
        with open(LOG_FILE, "a", encoding="utf-8") as f:
            f.write(f"{msg}\n")
    except Exception:
        pass

log_debug("=== Engine Process Started ===")

class GoogleInputToolsEngine(IBus.Engine):
    def __init__(self, **kwargs):
        super().__init__(**kwargs)
        log_debug("GoogleInputToolsEngine __init__ instantiated!")
        self.preedit = ""
        self.candidates = []
        self.user_dict = UserDictionaryManager()
        self.lookup_table = IBus.LookupTable.new(5, 0, True, True)
        self.lookup_table.set_orientation(IBus.Orientation.VERTICAL)

        # Connect GObject signals for IBus Engine events
        self.connect("process-key-event", self.on_process_key_event)
        self.connect("enable", self.on_enable)
        self.connect("disable", self.on_disable)
        self.connect("focus-in", self.on_focus_in)
        self.connect("focus-out", self.on_focus_out)
        self.connect("reset", self.on_reset)

    def on_enable(self, engine):
        log_debug("SIGNAL: enable called")

    def on_disable(self, engine):
        log_debug("SIGNAL: disable called")

    def on_focus_in(self, engine):
        log_debug("SIGNAL: focus-in called")

    def on_focus_out(self, engine):
        log_debug("SIGNAL: focus-out called")
        self.reset_state()

    def on_reset(self, engine):
        log_debug("SIGNAL: reset called")
        self.reset_state()

    def reset_state(self):
        self.preedit = ""
        self.candidates = []
        self.hide_preedit_text()
        self.hide_lookup_table()

    def fetch_candidates(self, text):
        if not text:
            return []
        raw_cands = []
        try:
            url = f"https://inputtools.google.com/request?text={urllib.parse.quote(text)}&itc=hi-t-i0-und&num=5&cp=0&cs=1&ie=utf-8&oe=utf-8"
            req = urllib.request.Request(url, headers={'User-Agent': 'Mozilla/5.0'})
            with urllib.request.urlopen(req, timeout=1.5) as resp:
                data = json.loads(resp.read().decode('utf-8'))
                if data[0] == 'SUCCESS' and len(data[1]) > 0:
                    raw_cands = data[1][0][1]
        except Exception as e:
            log_debug(f"Fetch error: {e}")

        if not raw_cands:
            raw_cands = [text]

        return self.user_dict.promote_candidates(text, raw_cands)

    def update_ui(self):
        log_debug(f"update_ui preedit: '{self.preedit}'")
        if not self.preedit:
            self.hide_preedit_text()
            self.hide_lookup_table()
            return

        text = IBus.Text.new_with_string(self.preedit)
        self.update_preedit_text(text, len(self.preedit), True)

        self.candidates = self.fetch_candidates(self.preedit)
        self.lookup_table.clear()
        for cand in self.candidates:
            self.lookup_table.append_candidate(IBus.Text.new_with_string(cand))

        if self.candidates:
            self.update_lookup_table(self.lookup_table, True)

    def on_process_key_event(self, engine, keyval, keycode, state):
        log_debug(f"SIGNAL: process-key-event: keyval={keyval}, keycode={keycode}, state={state}")
        is_release = bool(state & IBus.ModifierType.RELEASE_MASK)
        if is_release:
            return False

        if keyval == IBus.KEY_BackSpace:
            if self.preedit:
                self.preedit = self.preedit[:-1]
                self.update_ui()
                return True
            return False

        if keyval in (IBus.KEY_space, IBus.KEY_Return, IBus.KEY_KP_Enter):
            if self.preedit:
                idx = self.lookup_table.get_cursor_pos()
                commit_str = self.candidates[idx] if idx < len(self.candidates) else (self.candidates[0] if self.candidates else self.preedit)
                if keyval == IBus.KEY_space:
                    commit_str += " "
                self.commit_text(IBus.Text.new_with_string(commit_str))
                self.preedit = ""
                self.update_ui()
                return True
            return False

        if IBus.KEY_1 <= keyval <= IBus.KEY_9 and self.preedit:
            idx = keyval - IBus.KEY_1
            if idx < len(self.candidates):
                self.commit_text(IBus.Text.new_with_string(self.candidates[idx] + " "))
                self.preedit = ""
                self.update_ui()
                return True

        if keyval in (IBus.KEY_Up, IBus.KEY_Down) and self.preedit:
            if keyval == IBus.KEY_Down:
                self.lookup_table.cursor_down()
            else:
                self.lookup_table.cursor_up()
            self.update_lookup_table(self.lookup_table, True)
            return True

        if 32 <= keyval <= 126:
            char = chr(keyval)
            self.preedit += char
            self.update_ui()
            return True

        return False

# Register GObject type for IBus Engine Factory
GObject.type_register(GoogleInputToolsEngine)

class Factory:
    def __init__(self, bus):
        self.bus = bus
        self.factory = IBus.Factory.new(bus.get_connection())
        self.factory.add_engine("google-input-tools-hi", GoogleInputToolsEngine.__gtype__)
        self.factory.connect("create-engine", self.create_engine)
        self.engine_count = 0
        log_debug("Factory initialized and connected")

    def create_engine(self, factory, engine_name):
        log_debug(f"Factory.create_engine requested for: {engine_name}")
        if engine_name == "google-input-tools-hi":
            self.engine_count += 1
            path = f"/org/freedesktop/IBus/Engine/{self.engine_count}"
            return GObject.new(GoogleInputToolsEngine, engine_name=engine_name, object_path=path)
        return None

def main():
    IBus.init()
    bus = IBus.Bus()
    if not bus.is_connected():
        log_debug("IBus not connected!")
        sys.exit(1)

    bus.request_name("org.freedesktop.IBus.GoogleInputTools", 0)
    log_debug("Requested D-Bus name: org.freedesktop.IBus.GoogleInputTools")

    factory = Factory(bus)

    component = IBus.Component.new(
        "org.freedesktop.IBus.GoogleInputTools",
        "Google Input Tools (Hindi)",
        "1.1",
        "GPL",
        "Google Input Tools for Ubuntu",
        "",
        "",
        "google-input-tools"
    )
    engine = IBus.EngineDesc.new(
        "google-input-tools-hi",
        "Google Input Tools (Hindi)",
        "Google Transliteration for Hindi with User Dictionary",
        "hi",
        "GPL",
        "",
        "",
        "default"
    )
    component.add_engine(engine)
    bus.register_component(component)
    log_debug("Component registered unconditionally with IBus bus")

    mainloop = GLib.MainLoop()
    log_debug("MainLoop running...")
    mainloop.run()

if __name__ == '__main__':
    main()
