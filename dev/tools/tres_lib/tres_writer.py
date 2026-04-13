"""TresWriter — declarative builder for Godot .tres resource files."""

from __future__ import annotations


def format_dict(d: dict) -> str:
    """Format a Python dict as a Godot Dictionary literal (string keys)."""
    if not d:
        return "{}"
    pairs = ", ".join(f'"{k}": {v}' for k, v in sorted(d.items()))
    return "{ " + pairs + " }"


def format_dict_auto_keys(d: dict) -> str:
    """Format a dict using bare int keys where possible, quoted otherwise."""
    if not d:
        return "{}"
    pairs: list[str] = []
    for k, v in sorted(d.items(), key=lambda x: str(x[0])):
        try:
            pairs.append(f"{int(k)}: {v}")
        except (ValueError, TypeError):
            pairs.append(f'"{k}": {v}')
    return "{ " + ", ".join(pairs) + " }"


class TresWriter:
    """Builds a .tres file incrementally."""

    def __init__(
        self,
        resource_type: str,
        script_class: str,
        uid: str,
        format_version: int = 3,
        load_steps: int | None = None,
    ) -> None:
        self._resource_type = resource_type
        self._script_class = script_class
        self._uid = uid
        self._format = format_version
        self._load_steps = load_steps
        self._ext_resources: list[str] = []
        self._sub_resources: list[list[str]] = []
        self._resource_fields: list[str] = []

    # ── Ext resources ───────────────────────────────────────

    def add_ext_resource(
        self,
        tag_id: str,
        res_type: str,
        path: str,
        uid: str = "",
    ) -> str:
        """Append an [ext_resource] entry. Returns tag_id."""
        uid_part = f' uid="{uid}"' if uid else ""
        self._ext_resources.append(
            f'[ext_resource type="{res_type}"{uid_part} '
            f'path="{path}" id="{tag_id}"]'
        )
        return tag_id

    # ── Sub resources ───────────────────────────────────────

    def add_sub_resource(
        self,
        sub_id: str,
        res_type: str,
        fields: list[str],
    ) -> str:
        """Append a [sub_resource] block. Returns sub_id."""
        block = [f'[sub_resource type="{res_type}" id="{sub_id}"]']
        block.extend(fields)
        self._sub_resources.append(block)
        return sub_id

    # ── Resource body ───────────────────────────────────────

    def add_field(self, line: str) -> None:
        """Append a raw field line to the [resource] body."""
        self._resource_fields.append(line)

    def add_field_str(self, key: str, value: str) -> None:
        self._resource_fields.append(f'{key} = "{value}"')

    def add_field_int(self, key: str, value: int) -> None:
        self._resource_fields.append(f"{key} = {int(value)}")

    def add_field_float(self, key: str, value: float) -> None:
        self._resource_fields.append(f"{key} = {float(value)}")

    def add_field_bool(self, key: str, value: bool) -> None:
        self._resource_fields.append(f"{key} = {str(value).lower()}")

    def add_field_ext_ref(self, key: str, tag_id: str | None) -> None:
        if tag_id:
            self._resource_fields.append(f'{key} = ExtResource("{tag_id}")')
        else:
            self._resource_fields.append(f"{key} = null")

    def add_field_sub_ref(self, key: str, sub_id: str | None) -> None:
        if sub_id:
            self._resource_fields.append(f'{key} = SubResource("{sub_id}")')
        else:
            self._resource_fields.append(f"{key} = null")

    def add_field_ext_ref_array(self, key: str, tag_ids: list[str]) -> None:
        refs = ", ".join(f'ExtResource("{t}")' for t in tag_ids)
        self._resource_fields.append(f"{key} = [{refs}]")

    def add_field_sub_ref_array(self, key: str, sub_ids: list[str]) -> None:
        refs = ", ".join(f'SubResource("{s}")' for s in sub_ids)
        self._resource_fields.append(f"{key} = [{refs}]")

    def add_field_dict(self, key: str, d: dict) -> None:
        self._resource_fields.append(f"{key} = {format_dict(d)}")

    def add_field_dict_auto_keys(self, key: str, d: dict) -> None:
        self._resource_fields.append(f"{key} = {format_dict_auto_keys(d)}")

    # ── Render ──────────────────────────────────────────────

    def render(self) -> str:
        """Produce the complete .tres file text."""
        load_part = ""
        if self._load_steps is not None:
            load_part = f" load_steps={self._load_steps}"

        header = (
            f'[gd_resource type="{self._resource_type}"'
            f' script_class="{self._script_class}"'
            f"{load_part}"
            f" format={self._format}"
            f' uid="{self._uid}"]'
        )

        lines: list[str] = [header, ""]
        lines.extend(self._ext_resources)

        for block in self._sub_resources:
            lines.append("")
            lines.extend(block)

        lines.append("")
        lines.append("[resource]")
        lines.extend(self._resource_fields)
        lines.append("")

        return "\n".join(lines)
