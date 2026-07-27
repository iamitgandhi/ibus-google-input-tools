import os
import sys
import json

CONFIG_DIR = os.path.expanduser('~/.config/ibus-google-input-tools')
USER_DICT_JSON = os.path.join(CONFIG_DIR, 'user_dict.json')

class UserDictionaryManager:
    def __init__(self):
        self.entries = {}
        self.ensure_config_dir()
        self.load_user_dict()

    def ensure_config_dir(self):
        os.makedirs(CONFIG_DIR, exist_ok=True)

    def load_user_dict(self):
        if os.path.exists(USER_DICT_JSON):
            try:
                with open(USER_DICT_JSON, 'r', encoding='utf-8') as f:
                    self.entries = json.load(f)
            except Exception as e:
                print(f"Error loading user dict: {e}", file=sys.stderr)
                self.entries = {}

    def save_user_dict(self):
        try:
            with open(USER_DICT_JSON, 'w', encoding='utf-8') as f:
                json.dump(self.entries, f, ensure_ascii=False, indent=2)
        except Exception as e:
            print(f"Error saving user dict: {e}", file=sys.stderr)

    def import_dic_file(self, filepath):
        """Imports Google Input Tools / custom tab-separated .dic file"""
        if not os.path.exists(filepath):
            print(f"File not found: {filepath}")
            return False

        count = 0
        with open(filepath, 'r', encoding='utf-8', errors='ignore') as f:
            for line in f:
                line = line.strip()
                if not line or line.startswith('#'):
                    continue
                parts = line.split('\t')
                if len(parts) >= 2:
                    latin = parts[0].strip().lower()
                    target = parts[1].strip()
                    prio = int(parts[2].strip()) if (len(parts) >= 3 and parts[2].strip().isdigit()) else 1
                    
                    if latin not in self.entries:
                        self.entries[latin] = []
                    
                    existing_targets = [item['target'] for item in self.entries[latin]]
                    if target not in existing_targets:
                        self.entries[latin].append({'target': target, 'priority': prio})
                        count += 1
        self.save_user_dict()
        print(f"Successfully imported {count} entries from {filepath}")
        return True

    def export_dic_file(self, filepath):
        """Exports user dictionary to tab-separated .dic format"""
        lines = []
        for latin, items in self.entries.items():
            for item in items:
                lines.append(f"{latin}\t{item['target']}\t{item.get('priority', 1)}")
        with open(filepath, 'w', encoding='utf-8') as f:
            f.write('\n'.join(lines) + '\n')
        print(f"Successfully exported {len(lines)} entries to {filepath}")
        return True

    def promote_candidates(self, latin, candidates):
        latin_key = latin.strip().lower()
        if latin_key not in self.entries:
            return candidates

        user_words = [item['target'] for item in self.entries[latin_key]]
        new_cands = list(user_words)
        for c in candidates:
            if c not in new_cands:
                new_cands.append(c)
        return new_cands
