"""Local Graphify support for Nix and patch files."""

from __future__ import annotations

import json
import os
import select
import shutil
import subprocess
import time
from pathlib import Path
from typing import Any


class _NilClient:
    def __init__(self, binary: str = "nil") -> None:
        self._process = subprocess.Popen(
            [binary],
            stdin=subprocess.PIPE,
            stdout=subprocess.PIPE,
            stderr=subprocess.DEVNULL,
            bufsize=0,
        )
        self._buffer = bytearray()
        self._request_id = 0

    def __enter__(self) -> "_NilClient":
        return self

    def __exit__(self, *_: object) -> None:
        self.close()

    def _send(self, message: dict[str, Any]) -> None:
        if self._process.stdin is None:
            raise RuntimeError("nil stdin is unavailable")
        body = json.dumps(message, separators=(",", ":")).encode()
        self._process.stdin.write(
            f"Content-Length: {len(body)}\r\n\r\n".encode() + body
        )
        self._process.stdin.flush()

    def _read_message(self, timeout: float) -> dict[str, Any]:
        if self._process.stdout is None:
            raise RuntimeError("nil stdout is unavailable")
        deadline = time.monotonic() + timeout
        marker = b"\r\n\r\n"

        def read_more() -> None:
            remaining = deadline - time.monotonic()
            if (
                remaining <= 0
                or not select.select([self._process.stdout], [], [], remaining)[0]
            ):
                raise TimeoutError("nil LSP response timed out")
            chunk = os.read(self._process.stdout.fileno(), 65536)
            if not chunk:
                raise RuntimeError("nil exited before replying")
            self._buffer.extend(chunk)

        while marker not in self._buffer:
            read_more()
        raw_headers, _, body = self._buffer.partition(marker)
        headers = {}
        for line in raw_headers.decode("ascii").split("\r\n"):
            name, value = line.split(":", 1)
            headers[name.lower()] = value.strip()
        length = int(headers["content-length"])
        while len(body) < length:
            read_more()
            raw_headers, _, body = self._buffer.partition(marker)
        payload = bytes(body[:length])
        self._buffer = bytearray(body[length:])
        return json.loads(payload)

    def request(
        self, method: str, params: dict[str, Any] | None = None, timeout: float = 5.0
    ) -> Any:
        self._request_id += 1
        request_id = self._request_id
        self._send(
            {
                "jsonrpc": "2.0",
                "id": request_id,
                "method": method,
                "params": params or {},
            }
        )
        while True:
            message = self._read_message(timeout)
            if message.get("id") == request_id and "method" not in message:
                if "error" in message:
                    raise RuntimeError(f"nil {method} failed: {message['error']}")
                return message.get("result")
            if "id" in message and "method" in message:
                self._send({"jsonrpc": "2.0", "id": message["id"], "result": None})

    def notify(self, method: str, params: dict[str, Any] | None = None) -> None:
        self._send({"jsonrpc": "2.0", "method": method, "params": params or {}})

    def close(self) -> None:
        if self._process.poll() is not None:
            return
        try:
            self.request("shutdown", timeout=1.0)
            self.notify("exit")
            self._process.wait(timeout=1.0)
        except (OSError, RuntimeError, TimeoutError, subprocess.TimeoutExpired):
            self._process.terminate()
            try:
                self._process.wait(timeout=1.0)
            except subprocess.TimeoutExpired:
                self._process.kill()
                self._process.wait()


def extract_nix(path: Path) -> dict[str, Any]:
    from graphify.extractors.base import _file_stem, _make_id

    path = Path(path)
    str_path = str(path)
    try:
        source = path.read_text(encoding="utf-8", errors="replace")
    except OSError as error:
        return {"nodes": [], "edges": [], "error": str(error)}

    stem = _file_stem(path)
    file_id = _make_id(stem)
    nodes = [
        {
            "id": file_id,
            "label": path.name,
            "file_type": "code",
            "source_file": str_path,
            "source_location": "L1",
        }
    ]
    edges: list[dict[str, Any]] = []
    seen_nodes = {file_id}
    seen_edges: set[tuple[str, str]] = set()

    if shutil.which("nil") is None:
        return {"nodes": nodes, "edges": edges, "error": "nil not installed"}

    try:
        resolved = path.resolve()
        # ponytail: one nil process per file; share one only if startup dominates large repos.
        with _NilClient() as client:
            client.request(
                "initialize",
                {
                    "processId": os.getpid(),
                    "rootUri": resolved.parent.as_uri(),
                    "capabilities": {
                        "textDocument": {
                            "documentSymbol": {
                                "hierarchicalDocumentSymbolSupport": True
                            }
                        }
                    },
                },
            )
            client.notify("initialized")
            client.notify(
                "textDocument/didOpen",
                {
                    "textDocument": {
                        "uri": resolved.as_uri(),
                        "languageId": "nix",
                        "version": 1,
                        "text": source,
                    }
                },
            )
            symbols = (
                client.request(
                    "textDocument/documentSymbol",
                    {"textDocument": {"uri": resolved.as_uri()}},
                )
                or []
            )
    except (
        KeyError,
        OSError,
        RuntimeError,
        TimeoutError,
        TypeError,
        ValueError,
    ) as error:
        return {"nodes": nodes, "edges": edges, "error": f"nil LSP failed: {error}"}

    def add_symbols(
        items: list[dict[str, Any]], parent_label: str, parent_id: str
    ) -> None:
        for symbol in items:
            name = str(symbol.get("name") or "").strip()
            if not name:
                continue
            label = f"{parent_label}.{name}" if parent_label else name
            symbol_range = (
                symbol.get("range") or symbol.get("location", {}).get("range") or {}
            )
            start = max(0, int(symbol_range.get("start", {}).get("line", 0)))
            end = max(start, int(symbol_range.get("end", {}).get("line", start)))
            node_id = _make_id(stem, label)
            if node_id not in seen_nodes:
                seen_nodes.add(node_id)
                nodes.append(
                    {
                        "id": node_id,
                        "label": label,
                        "file_type": "code",
                        "source_file": str_path,
                        "source_location": f"L{start + 1}",
                        "source_end_location": f"L{end + 1}",
                        "symbol_kind": symbol.get("kind"),
                    }
                )
            edge = (parent_id, node_id)
            if parent_id != node_id and edge not in seen_edges:
                seen_edges.add(edge)
                edges.append(
                    {
                        "source": parent_id,
                        "target": node_id,
                        "relation": "contains",
                        "confidence": "EXTRACTED",
                        "source_file": str_path,
                        "source_location": f"L{start + 1}",
                        "weight": 1.0,
                    }
                )
            add_symbols(symbol.get("children") or [], label, node_id)

    add_symbols(symbols, "", file_id)
    return {"nodes": nodes, "edges": edges}


def install() -> None:
    from graphify import detect, extract

    detect.CODE_EXTENSIONS.add(".nix")
    detect.DOC_EXTENSIONS.add(".patch")
    extract._DISPATCH[".nix"] = extract_nix
