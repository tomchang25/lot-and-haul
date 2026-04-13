"""Pure functions for parsing .tres files (header, fields, resources)."""

import re


def header_uid(text: str) -> str | None:
    m = re.search(r'\[gd_resource[^\]]*uid="([^"]+)"', text)
    return m.group(1) if m else None


def ext_resources(text: str) -> dict[str, dict[str, str]]:
    out: dict[str, dict[str, str]] = {}
    for m in re.finditer(r"\[ext_resource([^\]]+)\]", text):
        a = m.group(1)

        def _a(k: str) -> str:
            r = re.search(rf'(?<![a-z]){k}="([^"]+)"', a)
            return r.group(1) if r else ""

        tag = _a("id")
        if tag:
            out[tag] = {"uid": _a("uid"), "path": _a("path"), "type": _a("type")}
    return out


def field(text: str, key: str) -> str | None:
    """Read a scalar field from a .tres [resource] block.

    Captures everything to end-of-line and strips surrounding quotes, so
    string literals like `display_name = "Foo"` and expression values like
    `unlock_action = SubResource("unlock")` are both returned verbatim
    (without the outer quotes for pure strings).
    """
    m = re.search(rf"^{re.escape(key)}\s*=\s*(.+?)\s*$", text, re.MULTILINE)
    if not m:
        return None
    val = m.group(1).strip()
    if len(val) >= 2 and val.startswith('"') and val.endswith('"'):
        val = val[1:-1]
    return val


def sub_resources(text: str) -> dict[str, dict[str, str]]:
    subs: dict[str, dict[str, str]] = {}
    for bm in re.finditer(
        r'\[sub_resource[^\]]*id="([^"]+)"\](.*?)(?=\n\[|\Z)', text, re.DOTALL
    ):
        fields: dict[str, str] = {}
        for line in bm.group(2).splitlines():
            m = re.match(r"(\w+)\s*=\s*(.+)", line.strip())
            if m:
                fields[m.group(1)] = m.group(2).strip().strip('"')
        subs[bm.group(1)] = fields
    return subs


def split_dict_pairs(body: str) -> list[str]:
    """Split key:value pairs on top-level commas, respecting nested {}/[]."""
    pairs: list[str] = []
    depth = 0
    buf: list[str] = []
    for ch in body:
        if ch in "{[":
            depth += 1
        elif ch in "}]":
            depth -= 1
        if ch == "," and depth == 0:
            pairs.append("".join(buf))
            buf = []
        else:
            buf.append(ch)
    if buf:
        pairs.append("".join(buf))
    return pairs


def parse_godot_dict(text: str) -> dict:
    """Parse a Godot Dictionary literal like { "foo": 1, "bar": 2 }."""
    text = (text or "").strip()
    if not (text.startswith("{") and text.endswith("}")):
        return {}
    body = text[1:-1].strip()
    if not body:
        return {}
    out: dict = {}
    for pair in split_dict_pairs(body):
        km = re.match(r'^\s*"([^"]*)"\s*:\s*(.+?)\s*$', pair)
        if not km:
            continue
        key = km.group(1)
        val_s = km.group(2).strip()
        try:
            out[key] = int(val_s)
        except ValueError:
            try:
                out[key] = float(val_s)
            except ValueError:
                out[key] = val_s.strip('"')
    return out
