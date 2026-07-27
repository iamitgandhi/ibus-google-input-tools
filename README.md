# Google Input Tools for Ubuntu Linux (IBus Engine)

A native **IBus Input Method Engine** for **Ubuntu Linux** that provides authentic **Google Input Tools phonetic transliteration** for Hindi — powered by the live Google API, with custom **User Dictionary (`.dic`) support**, zero-lag candidate popup, and seamless GNOME integration.

![Ubuntu IBus](https://img.shields.io/badge/Platform-Ubuntu%20%7C%20Debian%20%7C%20Linux-orange)
![License](https://img.shields.io/badge/License-GPL--3.0-blue)
![IBus](https://img.shields.io/badge/Input%20Method-IBus%20%2B%20m17n-green)

---

## ✨ Features

- **Live Google Transliteration API** — Real-time Hindi suggestions from Google's Input Tools service
- **User Dictionary Promotion** — Import your `.dic` files (e.g. `gg.dic` from Windows) and custom words appear as Candidate #1
- **Zero-Lag Typing** — 0ms candidate delay, auto-select first suggestion
- **Smart Candidate Box** — 5 numbered candidates, Space/Enter commits #1, number keys for others
- **GNOME Integration** — Top bar shows **`हि`** symbol, dropdown shows **`Hindi (इंडिया)`**
- **Works Everywhere** — LibreOffice Writer, Chrome, VS Code, Terminal, all GTK/Qt apps
- **m17n ITRANS Scheme** — Full Devanagari syllable rules + fast-typing shortcuts (`krne→करने`, `ptr→पत्र`)
- **Offline Fallback** — Falls back to Hunspell dictionary when offline

---

## 🚀 Quick Setup (One Command)

```bash
git clone https://github.com/iamitgandhi/ibus-google-input-tools.git
cd ibus-google-input-tools
chmod +x setup_google_input_tools.sh
sudo bash setup_google_input_tools.sh
```

The setup script handles **everything**:
1. Installs system packages (`ibus`, `ibus-m17n`, `m17n-db`, `ibus-typing-booster`, `hunspell-hi`)
2. Configures IBus environment variables
3. Installs `hi-git-itrans.mim` m17n scheme
4. Patches `hunspell_suggest.py` with Google API integration
5. Patches `main.py` with Hindi UI labels
6. Applies dconf/GSettings configuration
7. Sets GNOME input sources
8. Rebuilds IBus cache and restarts daemon

> **Note:** The setup script is **idempotent** — safe to run multiple times. Re-run it after `apt upgrade` to re-apply patches.

---

## 📋 Manual Installation

### 1. Install System Packages

```bash
sudo apt update
sudo apt install ibus ibus-m17n m17n-db ibus-typing-booster hunspell-hi
```

### 2. Set IBus Environment Variables

Add to `~/.profile` and `~/.bashrc`:

```bash
export GTK_IM_MODULE=ibus
export QT_IM_MODULE=ibus
export XMODIFIERS=@im=ibus
```

### 3. Install m17n Scheme

Copy `hi-git-itrans.mim` to:
```bash
mkdir -p ~/.m17n.d/
cp hi-git-itrans.mim ~/.m17n.d/
```

### 4. Apply Patches & Configuration

```bash
sudo bash setup_google_input_tools.sh
```

### 5. Verify Installation

```bash
bash verify_setup.sh
```

---

## ⌨️ How to Use

1. **Switch to Hindi**: Press `Super+Space`
2. **Type in English**: e.g. `nyayadhish`, `mukhya`, `seva`
3. **Candidates appear**: First suggestion auto-highlighted
4. **Commit**: Press `Space` (adds space) or `Enter` (no space)
5. **Select alternate**: Press `2`, `3`, `4`, `5` or use `Tab`/`↓`/`↑`
6. **Cancel**: Press `Escape`
7. **Switch back to English**: Press `Super+Space`

---

## 📖 User Dictionary (`.dic`) Management

### Import your `.dic` file (e.g. `gg.dic` from Google Input Tools for Windows):
```bash
ibus-git-dict --import-dic /path/to/gg.dic
```

### Export user dictionary:
```bash
ibus-git-dict --export-dic ~/my_custom_dict.dic
```

### Add a custom word pair:
```bash
ibus-git-dict --add "mukhya" "मुख्य"
```

### List all dictionary entries:
```bash
ibus-git-dict --list
```

### `.dic` File Format
Tab-separated with optional priority:
```
mukhya	मुख्य	1
seva	सेवा	1
shriman	श्रीमान	1
nyayadhish	न्यायाधीश	1
```

---

## ⚡ dconf / GSettings Configuration

The setup script applies these settings automatically. To apply manually:

```bash
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
  dconf write "${P}autoselectcandidate" 2
  dconf write "${P}candidatesdelaymilliseconds" 0
  dconf write "${P}avoidforwardkeyevent" true
  dconf write "${P}inputmodetruesymbol" "'हि'"
  dconf write "${P}keybindings" "{'cancel': <['Escape']>, 'commit': <['Return', 'KP_Enter']>, 'commit_and_forward_key': <@as []>, 'commit_candidate_1_plus_space': <['1', 'KP_1', 'F1']>, 'commit_candidate_2_plus_space': <['2', 'KP_2', 'F2']>, 'commit_candidate_3_plus_space': <['3', 'KP_3', 'F3']>, 'commit_candidate_4_plus_space': <['4', 'KP_4', 'F4']>, 'commit_candidate_5_plus_space': <['5', 'KP_5', 'F5']>, 'select_next_candidate': <['Tab', 'ISO_Left_Tab', 'Down', 'KP_Down']>, 'select_previous_candidate': <['Shift+Tab', 'Shift+ISO_Left_Tab', 'Up', 'KP_Up']>}"
done

gsettings set org.gnome.desktop.input-sources sources "[('ibus', 'typing-booster'), ('xkb', 'us')]"
gsettings set org.gnome.desktop.input-sources current 0

sudo ibus write-cache
ibus write-cache
ibus restart
```

---

## 🏗️ Architecture

```
┌─────────────────────────────────────────────────┐
│                  GNOME Desktop                   │
│            Hindi (इंडिया) हि                      │
├─────────────────────────────────────────────────┤
│                IBus Framework                    │
│          ibus-typing-booster engine              │
├──────────────┬──────────────┬───────────────────┤
│  m17n ITRANS │  Google API  │  User Dictionary   │
│ hi-git-itrans│  Live REST   │  user_dict.json    │
│   .mim       │  Suggestions │  (gg.dic import)   │
├──────────────┴──────────────┴───────────────────┤
│             hunspell-hi Dictionary               │
│           (offline fallback)                     │
└─────────────────────────────────────────────────┘
```

---

## 📂 File Structure

```text
ibus-google-input-tools/
├── setup_google_input_tools.sh   # 🚀 Master setup (run this!)
├── verify_setup.sh               # ✅ 22-check verification suite
├── ibus-git-repatch.sh           # 🔄 Auto-repatch script triggered by APT
├── ibus-google-input-tools.py    # Standalone IBus engine (alternative)
├── user_dict_manager.py          # Dictionary import/export/promotion
├── ibus-git-dict.py              # CLI dictionary management tool
├── google-input-tools-hi.xml     # IBus component XML registration
├── install_user.sh               # User-level installer
├── install.sh                    # System-level installer
├── register_system.sh            # System registration script
├── register_user.sh              # User registration script
├── update_system.sh              # System update script
├── fix_exec.sh                   # Execution fix script
├── .gitignore                    # Git ignore rules
└── README.md                     # This file
```

---

## 🛡️ Package Update Protection (APT Hook)

The setup script automatically installs an **APT Post-Invoke hook** at `/etc/apt/apt.conf.d/99-ibus-google-input-tools` and script at `/usr/local/bin/ibus-git-repatch.sh`.

Whenever `apt upgrade` updates `ibus-typing-booster`, the APT hook automatically detects that the files were overwritten and **re-applies the Google Input Tools patches instantly**.

You never have to worry about system updates breaking your Hindi transliteration!

To manually re-apply patches at any time:
```bash
sudo ibus-git-repatch.sh
```

---

## 🎯 Verification

Run the verification script to check all 22 components:

```bash
bash verify_setup.sh
```

Expected output:
```
✅ Passed: 22
❌ Failed: 0
⚠️  Warnings: 0
🎉 ALL CHECKS PASSED! System is ready.
```

---

## License

GPL-3.0 License
