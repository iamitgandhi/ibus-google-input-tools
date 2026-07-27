#!/usr/bin/env python3
import sys
import os
import argparse

# Add engine directory to sys.path
sys.path.insert(0, os.path.expanduser('~/.local/share/ibus-google-input-tools'))
sys.path.insert(0, '/usr/share/ibus-google-input-tools')

from user_dict_manager import UserDictionaryManager

def main():
    parser = argparse.ArgumentParser(description="Google Input Tools User Dictionary Manager (Ubuntu)")
    parser.add_argument('--import-dic', type=str, help="Path to .dic file to import (e.g. gg.dic)")
    parser.add_argument('--export-dic', type=str, help="Path to export dictionary to .dic file")
    parser.add_argument('--list', action='store_true', help="List all user dictionary entries")
    parser.add_argument('--add', nargs=2, metavar=('LATIN', 'HINDI'), help="Add a custom word pair (e.g. --add mukhya मुख्य)")

    args = parser.parse_args()
    ud = UserDictionaryManager()

    if args.import_dic:
        print(f"Importing dictionary from: {args.import_dic}")
        ud.import_dic_file(args.import_dic)

    elif args.export_dic:
        print(f"Exporting dictionary to: {args.export_dic}")
        ud.export_dic_file(args.export_dic)

    elif args.add:
        latin, target = args.add
        if latin not in ud.entries:
            ud.entries[latin] = []
        ud.entries[latin].insert(0, {'target': target, 'priority': 1})
        ud.save_user_dict()
        print(f"Added shortcut: '{latin}' -> '{target}'")

    elif args.list:
        print("=== Current User Dictionary Entries ===")
        for k, v in ud.entries.items():
            print(f"{k} -> {[item['target'] for item in v]}")

    else:
        parser.print_help()

if __name__ == '__main__':
    main()
