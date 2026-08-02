#!/usr/bin/env python3
"""Render OpenCode JSON events while preserving the raw JSONL stream."""

import argparse
import json
import sys
from pathlib import Path


def describe_tool(part: dict) -> str:
    tool = str(part.get("tool", "tool"))
    state = part.get("state") or {}
    status = state.get("status", "unknown")
    if status == "error":
        return f"TOOL_ERROR: {tool}: {state.get('error', 'unknown error')}"
    details = state.get("title") or state.get("input") or ""
    if isinstance(details, (dict, list)):
        details = json.dumps(details, ensure_ascii=False)
    line = f"TOOL_OK: {tool}"
    if details:
        line += f": {details}"
    output = state.get("output")
    if output and tool in {"bash", "shell", "edit", "write"}:
        line += f"\n{output}"
    return line


def render(event: dict) -> str:
    kind = event.get("type")
    if kind == "text":
        return str((event.get("part") or {}).get("text", "")).strip()
    if kind == "tool_use":
        return describe_tool(event.get("part") or {})
    if kind == "error":
        return "SESSION_ERROR: " + json.dumps(event.get("error"), ensure_ascii=False)
    return ""


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("--raw-log", required=True)
    parser.add_argument("--append", action="store_true")
    args = parser.parse_args()
    mode = "a" if args.append else "w"
    raw_path = Path(args.raw_log)
    raw_path.parent.mkdir(parents=True, exist_ok=True)
    with raw_path.open(mode, encoding="utf-8", newline="\n") as raw:
        for source_line in sys.stdin:
            raw.write(source_line)
            try:
                output = render(json.loads(source_line))
            except json.JSONDecodeError:
                output = source_line.rstrip()
            if output:
                print(output, flush=True)
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
