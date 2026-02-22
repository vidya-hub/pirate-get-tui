# pirate-get

> 🏴‍☠️ A command-line and TUI tool for searching torrents

[![License](https://img.shields.io/badge/license-AGPL--3.0-blue.svg)](LICENSE)
[![Python](https://img.shields.io/badge/python-3.8+-green.svg)](https://python.org)
[![Release](https://img.shields.io/github/v/release/vidya-hub/pirate-get-tui)](https://github.com/vidya-hub/pirate-get-tui/releases)

pirate-get is a convenient command-line tool (inspired by APT) to speed up your trip to The Pirate Bay and get your completely legal torrents more quickly. Now with a modern **Terminal User Interface (TUI)**!

## ✨ Features

- **TUI Mode**: Modern, keyboard-driven terminal interface with cyberpunk theme
- **CLI Mode**: Classic command-line interface for scripting
- **Card-Based Results**: Visual torrent cards with health indicators
- **Toast Notifications**: Action feedback in the TUI
- **Transmission Integration**: Send torrents directly to Transmission
- **Multiple Mirrors**: Automatic failover between mirrors

## 📸 Screenshots

### TUI Mode
![Main Interface](docs/screenshots/01-main-interface.svg)
![Search Results](docs/screenshots/02-search-results.svg)

> 📖 See [TUI Documentation](docs/TUI.md) for full feature guide

## 🚀 Quick Install

```bash
# One-line install (Ubuntu/macOS)
curl -fsSL https://raw.githubusercontent.com/vidya-hub/pirate-get-tui/main/install.sh | bash
```

### Alternative Methods

```bash
# Via pip
pip install pirate-get

# From releases (Ubuntu)
wget https://github.com/vidya-hub/pirate-get-tui/releases/download/v1.0.0/pirate-get_1.0.0_all.deb
sudo dpkg -i pirate-get_1.0.0_all.deb

# From releases (macOS)
wget https://github.com/vidya-hub/pirate-get-tui/releases/download/v1.0.0/pirate-get-1.0.0-macos.tar.gz
tar -xzf pirate-get-1.0.0-macos.tar.gz
cd pirate-get-1.0.0-macos && ./install.sh
```

## 📖 Usage

### TUI Mode (Recommended)

```bash
# Launch TUI with search
pirate-get --tui "ubuntu"

# Launch interactive TUI
pirate-get --tui
```

### CLI Mode

```bash
# Search for torrents
pirate-get "ubuntu 24.04"

# See all options
pirate-get -h
```

### TUI Keyboard Shortcuts

| Key | Action |
|-----|--------|
| `/` | Focus search |
| `Enter` | Toggle details |
| `j`/`k` | Navigate up/down |
| `m` | Copy magnet |
| `o` | Open in browser |
| `t` | Save .torrent |
| `s` | Save .magnet |
| `x` | Send to Transmission |
| `q` | Quit |

## ⚙️ Configuration

Create `~/.config/pirate-get`:

```ini
[Save]
directory = ~/Downloads
magnets = false
torrents = false

[Search]
total-results = 50

[Misc]
openCommand =
transmission = false
transmission-auth =
transmission-port =
colors = true
mirror = https://thepiratebay.org
```

## 🔧 Requirements

- Python 3.8+
- pip
- Terminal with Unicode support (for TUI)

## 📦 From Source

```bash
git clone https://github.com/vidya-hub/pirate-get-tui.git
cd pirate-get-tui
pip install -e .
```

## 📄 License

pirate-get is licensed under the [GNU Affero General Public License v3.0](LICENSE).

## 🙏 Credits

- Original project: [vikstrous/pirate-get](https://github.com/vikstrous/pirate-get)
- TUI built with [Textual](https://textual.textualize.io/)
