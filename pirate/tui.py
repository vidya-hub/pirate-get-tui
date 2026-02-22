"""
pirate-get TUI — A proper terminal user interface for searching torrents.

Built with Textual. Replaces the old print-based interactive loop with a
full-featured TUI featuring search, sortable results, detail view, and
keyboard-driven torrent actions.
"""

import sys
import os
import socket
import subprocess
import webbrowser
import urllib.error
from pathlib import Path
from functools import partial

from textual import work
from textual.app import App, ComposeResult
from textual.binding import Binding
from textual.containers import Horizontal, Vertical, Container
from textual.widgets import (
    Header,
    Footer,
    ListView,
    ListItem,
    Input,
    Select,
    Static,
    LoadingIndicator,
    Label,
    ProgressBar,
)
from textual.worker import Worker, WorkerState

import pirate.data
import pirate.torrent
import pirate.local


# ── Category / sort helpers ──────────────────────────────────────────────


def _category_options():
    """Yield (label, value) pairs for the category Select widget."""
    for name, cid in sorted(pirate.data.categories.items(), key=lambda x: x[1]):
        yield (name, cid)


def _sort_options():
    """Yield (label, value) pairs for the sort Select widget."""
    for name in pirate.data.sorts:
        yield (name, name)


# ── Custom Widgets ──────────────────────────────────────────────────────


class HealthBar(Static):
    """Visual indicator for torrent health based on seeders."""

    def __init__(self, seeders: int):
        super().__init__()
        self.seeders = seeders

    def render(self):
        width = 10
        filled = min(
            width, max(1, int(self.seeders / 10))
        )  # 1 block per 10 seeders, max 10
        color = "red"
        if self.seeders >= 50:
            color = "green"
        elif self.seeders >= 10:
            color = "yellow"

        bar = "█" * filled + "░" * (width - filled)
        return f"[{color}]{bar}[/]"


class TorrentItem(ListItem):
    """A card-like list item for a torrent result."""

    def __init__(self, result: dict, index: int):
        super().__init__()
        self.result = result
        self.index = index
        self.add_class("torrent-item")

    def compose(self) -> ComposeResult:
        name = self.result.get("name", "Unknown")
        size = self.result.get("size", "?")
        seeders = int(self.result.get("seeders", 0))
        leechers = int(self.result.get("leechers", 0))
        uploaded = self.result.get("uploaded", "")
        category = self.result.get("category", "")

        # Calculate health color
        health_color = "red"
        if seeders >= 50:
            health_color = "green"
        elif seeders >= 10:
            health_color = "yellow"

        with Vertical(classes="card-container"):
            with Horizontal(classes="card-header"):
                yield Label(f"{self.index + 1}. {name}", classes="card-title")
                yield Label(
                    f"[{health_color}]Seeds: {seeders}[/] · Leech: {leechers}",
                    classes="card-stats",
                )

            with Horizontal(classes="card-details"):
                yield Label(f"💾 {size}", classes="detail-pill size")
                yield Label(f"📅 {uploaded}", classes="detail-pill uploaded")
                if category:
                    yield Label(f"🏷️ {category}", classes="detail-pill category")

            # Visual health bar at bottom of card
            yield HealthBar(seeders)


# ── The TUI App ──────────────────────────────────────────────────────────


class PirateGetApp(App):
    """A TUI for searching and downloading torrents from The Pirate Bay."""

    CSS_PATH = "tui.tcss"
    TITLE = "pirate-get"

    BINDINGS = [
        Binding("q", "quit", "Quit", show=True),
        Binding("slash", "focus_search", "Search", show=True, key_display="/"),
        Binding("j", "cursor_down", "Down", show=False),
        Binding("k", "cursor_up", "Up", show=False),
        Binding("g", "cursor_top", "Top", show=False),
        Binding("shift+g", "cursor_bottom", "Bottom", show=False, key_display="G"),
        Binding("enter", "toggle_detail", "Details", show=True),
        Binding("m", "copy_magnet", "Copy Magnet", show=True),
        Binding("o", "open_browser", "Open", show=True),
        Binding("t", "save_torrent", "Save .torrent", show=True),
        Binding("s", "save_magnet", "Save .magnet", show=True),
        Binding("x", "send_transmission", "Transmission", show=True),
        Binding("r", "refresh", "Refresh", show=False),
        Binding("escape", "close_detail_or_blur", "Back", show=False),
    ]

    def __init__(
        self,
        mirrors=None,
        timeout=None,
        save_directory=None,
        transmission_command=None,
        open_command=None,
        database=None,
        use_local=False,
        initial_search=None,
        initial_category="All",
        initial_sort="SeedersDsc",
        total_results=50,
    ):
        super().__init__()
        self.mirrors = mirrors or [pirate.data.default_mirror]
        self.timeout = timeout or pirate.data.default_timeout
        self.save_directory = save_directory or os.getcwd()
        self.transmission_command = transmission_command or ["transmission-remote"]
        self.open_command = open_command
        self.database = database
        self.use_local = use_local
        self.initial_search = initial_search
        self.initial_category = initial_category
        self.initial_sort = initial_sort
        self.total_results = total_results

        self._results = []
        self._current_mirror = None

    # ── Compose ──────────────────────────────────────────────────────

    def compose(self) -> ComposeResult:
        yield Header()

        with Horizontal(id="search-bar"):
            yield Input(
                placeholder="Search torrents… (press / to focus)",
                id="search-input",
            )
            yield Select(
                list(_category_options()),
                value=pirate.data.categories.get(self.initial_category, 0),
                id="category-select",
                allow_blank=False,
            )
            yield Select(
                list(_sort_options()),
                value=self.initial_sort,
                id="sort-select",
                allow_blank=False,
            )

        with Container(id="main-content"):
            yield ListView(id="results-list")
            yield Static(
                "🏴‍☠️  Search for torrents above, or press / to start typing",
                id="empty-state",
            )

        with Vertical(id="detail-panel"):
            yield Label("", id="detail-title")
            yield Static("", id="detail-info")

        yield Static("Ready", id="status-bar")
        yield Footer()

    # ── Mount ────────────────────────────────────────────────────────

    def on_mount(self) -> None:
        # Initial setup if needed
        pass

        if self.initial_search:
            input_widget = self.query_one("#search-input", Input)
            input_widget.value = (
                " ".join(self.initial_search)
                if isinstance(self.initial_search, list)
                else self.initial_search
            )
            self._do_search()

    # ── Search ───────────────────────────────────────────────────────

    def on_input_submitted(self, event: Input.Submitted) -> None:
        if event.input.id == "search-input":
            self._do_search()

    def _do_search(self) -> None:
        query = self.query_one("#search-input", Input).value.strip()
        if not query:
            self._set_status("Enter a search term", "warning")
            return

        category = self.query_one("#category-select", Select).value
        sort_key = self.query_one("#sort-select", Select).value

        self._set_status(f"Searching for '{query}'…")
        self._hide_detail()
        self._run_search(query, category, sort_key)

    @work(exclusive=True, thread=True, group="search")
    def _run_search(self, query: str, category: int, sort_key: str) -> None:
        """Run the torrent search in a background thread."""
        terms = query.split()
        sort = pirate.torrent.parse_sort(_StatusPrinter(), sort_key)

        if self.use_local and self.database:
            if os.path.isfile(self.database):
                results = pirate.local.search(self.database, terms)
                self._current_mirror = None
            else:
                self.call_from_thread(
                    self._set_status,
                    f"Local database not found: {self.database}",
                    "error",
                )
                return
        else:
            results = None
            for mirror in self.mirrors:
                try:
                    url = pirate.torrent.find_api(mirror, self.timeout)
                    results = pirate.torrent.remote(
                        printer=_StatusPrinter(),
                        pages=1,
                        category=category,
                        sort=sort,
                        mode="search",
                        terms=terms,
                        mirror=url,
                        timeout=self.timeout,
                    )
                    self._current_mirror = mirror
                    break
                except (urllib.error.URLError, socket.timeout, IOError, ValueError):
                    continue

            if results is None:
                self.call_from_thread(
                    self._set_status,
                    "All mirrors failed. Try again later.",
                    "error",
                )
                return

        if self.total_results:
            results = results[: self.total_results]

        self._results = results
        self.call_from_thread(self._populate_table, results)

    def _populate_table(self, results: list) -> None:
        """Populate the ListView with TorrentCard widgets."""
        list_view = self.query_one("#results-list", ListView)
        empty = self.query_one("#empty-state", Static)

        list_view.clear()

        if not results:
            list_view.display = False
            empty.update("No results found. Try a different search term.")
            empty.display = True
            self._set_status("No results")
            return

        empty.display = False
        list_view.display = True

        for i, r in enumerate(results):
            list_view.append(TorrentItem(r, i))

        self._set_status(
            f"Found {len(results)} result{'s' if len(results) != 1 else ''}"
            + (f"  ·  Mirror: {self._current_mirror}" if self._current_mirror else "")
        )
        list_view.focus()

    # ── Detail Panel ─────────────────────────────────────────────────

    def action_toggle_detail(self) -> None:
        panel = self.query_one("#detail-panel")
        if panel.has_class("visible"):
            self._hide_detail()
        else:
            self._show_detail()

    def _show_detail(self) -> None:
        result = self._selected_result()
        if result is None:
            return

        panel = self.query_one("#detail-panel")
        title = self.query_one("#detail-title", Label)
        info = self.query_one("#detail-info", Static)

        seeders = result.get("seeders", "?")
        leechers = result.get("leechers", "?")
        size = result.get("size", "?")
        uploaded = result.get("uploaded", "?")
        category = result.get("category", "?")
        info_hash = result.get("info_hash", "?")

        title.update(result.get("name", "Unknown"))
        info.update(
            f"Size: {size}  ·  Seeders: {seeders}  ·  Leechers: {leechers}\n"
            f"Uploaded: {uploaded}  ·  Category: {category}\n"
            f"Info Hash: {info_hash if isinstance(info_hash, str) else format(info_hash, 'X')}"
        )
        panel.add_class("visible")

    def _hide_detail(self) -> None:
        self.query_one("#detail-panel").remove_class("visible")

    # ── Actions ──────────────────────────────────────────────────────

    def action_focus_search(self) -> None:
        self.query_one("#search-input", Input).focus()

    def action_close_detail_or_blur(self) -> None:
        panel = self.query_one("#detail-panel")
        if panel.has_class("visible"):
            self._hide_detail()
        else:
            list_view = self.query_one("#results-list", ListView)
            if list_view.display:
                list_view.focus()

    def action_cursor_down(self) -> None:
        list_view = self.query_one("#results-list", ListView)
        if list_view.display and len(list_view.children) > 0:
            list_view.action_cursor_down()

    def action_cursor_up(self) -> None:
        list_view = self.query_one("#results-list", ListView)
        if list_view.display and len(list_view.children) > 0:
            list_view.action_cursor_up()

    def action_cursor_top(self) -> None:
        list_view = self.query_one("#results-list", ListView)
        if list_view.display and len(list_view.children) > 0:
            list_view.index = 0

    def action_cursor_bottom(self) -> None:
        list_view = self.query_one("#results-list", ListView)
        if list_view.display and len(list_view.children) > 0:
            list_view.index = len(list_view.children) - 1

    def action_copy_magnet(self) -> None:
        result = self._selected_result()
        if result is None:
            return
        try:
            import pyperclip

            pyperclip.copy(result["magnet"])
            self.notify(
                f"Copied magnet link for: {result['name']}",
                title="📋 Copied",
                timeout=3,
            )
        except Exception as e:
            self.notify(
                f"Copy failed: {e}", title="❌ Error", severity="error", timeout=5
            )

    def action_open_browser(self) -> None:
        result = self._selected_result()
        if result is None:
            return
        url = result["magnet"]
        if self.open_command:
            from pirate.pirate import parse_cmd

            cmd = parse_cmd(self.open_command, url)
            subprocess.Popen(cmd, stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)
            self.notify(
                f"Opened: {result['name']}", title="🚀 Custom Command", timeout=3
            )
        else:
            webbrowser.open(url)
            self.notify(f"Opened: {result['name']}", title="🌐 Browser", timeout=3)

    def action_save_magnet(self) -> None:
        result = self._selected_result()
        if result is None:
            return
        torrent_name = result["name"].replace("/", "_").replace("\\", "_")
        filepath = os.path.join(self.save_directory, torrent_name + ".magnet")
        try:
            with open(filepath, "w") as f:
                f.write(result["magnet"] + "\n")
            self.notify(f"Saved: {filepath}", title="💾 Magnet Saved", timeout=3)
        except OSError as e:
            self.notify(
                f"Save failed: {e}", title="❌ Error", severity="error", timeout=5
            )

    def action_save_torrent(self) -> None:
        result = self._selected_result()
        if result is None:
            return
        self._set_status(f"Downloading torrent file for: {result['name']}…")
        self._download_torrent(result)

    @work(thread=True, group="download")
    def _download_torrent(self, result: dict) -> None:
        torrent_name = result["name"].replace("/", "_").replace("\\", "_")
        filepath = os.path.join(self.save_directory, torrent_name + ".torrent")
        try:
            torrent = pirate.torrent.get_torrent(result["info_hash"], self.timeout)
            with open(filepath, "wb") as f:
                f.write(torrent)
            self.call_from_thread(
                self.notify, f"Saved: {filepath}", title="💾 Torrent Saved", timeout=3
            )
        except Exception as e:
            self.call_from_thread(
                self.notify,
                f"Download failed: {e}",
                title="❌ Error",
                severity="error",
                timeout=5,
            )

    def action_send_transmission(self) -> None:
        result = self._selected_result()
        if result is None:
            return
        try:
            subprocess.call(
                self.transmission_command + ["--add", result["magnet"]],
                stdout=subprocess.DEVNULL,
                stderr=subprocess.DEVNULL,
            )
            self.notify(f"Sent: {result['name']}", title="📡 Transmission", timeout=3)
        except FileNotFoundError:
            self.notify(
                "transmission-remote not found",
                title="❌ Error",
                severity="error",
                timeout=5,
            )

    def action_refresh(self) -> None:
        self._do_search()

    # ── Helpers ──────────────────────────────────────────────────────

    def _selected_result(self):
        """Get the currently highlighted result, or None."""
        if not self._results:
            self._set_status("No results to act on", "warning")
            return None

        list_view = self.query_one("#results-list", ListView)
        if list_view.index is None:
            self._set_status("No row selected", "warning")
            return None

        return self._results[list_view.index]

    def _set_status(self, text: str, level: str = "info") -> None:
        bar = self.query_one("#status-bar", Static)
        prefix = {"info": "", "warning": "⚠ ", "error": "✗ "}.get(level, "")
        bar.update(f"{prefix}{text}")

    def on_list_view_highlighted(self, event: ListView.Highlighted) -> None:
        """Auto-update detail panel when cursor moves, if it's open."""
        panel = self.query_one("#detail-panel")
        if panel.has_class("visible"):
            self._show_detail()

    def on_list_view_selected(self, event: ListView.Selected) -> None:
        """Handle enter key on list item."""
        self.action_toggle_detail()


class _StatusPrinter:
    """A minimal printer interface that discards output, used for the
    torrent module which expects a printer object."""

    def print(self, *args, **kwargs):
        pass


# ── Entry point ──────────────────────────────────────────────────────────


def run_tui(args):
    """Launch the TUI with the given (already combined) args namespace."""
    app = PirateGetApp(
        mirrors=getattr(args, "mirror", None),
        timeout=getattr(args, "timeout", None),
        save_directory=getattr(args, "save_directory", None),
        transmission_command=getattr(args, "transmission_command", None),
        open_command=getattr(args, "open_command", None),
        database=getattr(args, "database", None),
        use_local=getattr(args, "source", "") == "local_tpb",
        initial_search=getattr(args, "search", None) or None,
        initial_category=getattr(args, "category", "All"),
        initial_sort=getattr(args, "sort", "SeedersDsc"),
        total_results=getattr(args, "total_results", 50),
    )
    app.run()


def main():
    """Standalone TUI entry point (no args)."""
    app = PirateGetApp()
    app.run()


if __name__ == "__main__":
    main()
