import importlib
import os
import re
import sys
import tempfile
import types
from pathlib import Path


def make_id(*parts: str) -> str:
    return re.sub(r"[^a-z0-9]+", "_", "_".join(parts).lower()).strip("_")


graphify = types.ModuleType("graphify")
graphify.__path__ = []
detect = types.ModuleType("graphify.detect")
detect.CODE_EXTENSIONS = set()
detect.DOC_EXTENSIONS = set()
extract = types.ModuleType("graphify.extract")
extract._DISPATCH = {}
extractors = types.ModuleType("graphify.extractors")
extractors.__path__ = []
base = types.ModuleType("graphify.extractors.base")
base._make_id = make_id
base._file_stem = lambda path: Path(path).with_suffix("").as_posix()
graphify.detect = detect
graphify.extract = extract
sys.modules.update(
    {
        "graphify": graphify,
        "graphify.detect": detect,
        "graphify.extract": extract,
        "graphify.extractors": extractors,
        "graphify.extractors.base": base,
    }
)

support = importlib.import_module("graphify_nix_support")
support.install()
assert detect.CODE_EXTENSIONS == {".nix"}
assert detect.DOC_EXTENSIONS == {".patch"}
assert extract._DISPATCH[".nix"] is support.extract_nix

with tempfile.TemporaryDirectory() as directory:
    source = Path(directory) / "module.nix"
    source.write_text(
        """{
  config.services.nginx = {
    enable = true;
    virtualHosts.localhost.forceSSL = true;
  };
}
""",
        encoding="utf-8",
    )
    result = support.extract_nix(source)
    path = os.environ["PATH"]
    try:
        os.environ["PATH"] = ""
        missing_nil = support.extract_nix(source)
    finally:
        os.environ["PATH"] = path

labels = {node["label"] for node in result["nodes"]}
assert "config.services.nginx.enable" in labels
assert "config.services.nginx.virtualHosts.localhost.forceSSL" in labels
node_ids = {node["id"] for node in result["nodes"]}
assert result["edges"]
assert all(edge["relation"] == "contains" for edge in result["edges"])
assert all(
    edge["source"] in node_ids and edge["target"] in node_ids
    for edge in result["edges"]
)
assert missing_nil["error"] == "nil not installed"
assert len(missing_nil["nodes"]) == 1
