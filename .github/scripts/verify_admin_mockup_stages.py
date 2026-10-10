#!/usr/bin/env python3
"""Fail CI if the 54-artboard review loses screens or points to missing code.

This is an inventory/safety gate, NOT a pixel-parity certification.
Screenshots and interaction tests are separate stage sign-off requirements.
"""
from __future__ import annotations

import json
import re
from pathlib import Path


def validate(root: Path) -> tuple[int, int]:
    design = root / "docs/design/admin-mockup"
    stages = json.loads((design / "ETAPAS.json").read_text(encoding="utf-8"))
    canvas = json.loads((design / "project/canvas.json").read_text(encoding="utf-8"))
    expected = canvas["order"]
    assert len(expected) == 54, f"Expected 54 boards; got {len(expected)}"
    assert len(stages["pages"]) == 54, "Manifest must contain exactly 54 pages"
    assert stages["total"] == 54, "Manifest total must be 54"

    seen_files, seen_pages = set(), set()
    step_numbers = {}
    for stage in stages["stages"]:
        label = stage["code"]
        assert label not in step_numbers, f"Duplicate stage {label}"
        step_numbers[label] = set(stage["pages"])
        assert step_numbers[label], f"Empty stage {label}"
        for page_number in step_numbers[label]:
            assert 1 <= page_number <= 54
    all_stage_pages = [n for numbers in step_numbers.values() for n in numbers]
    assert sorted(all_stage_pages) == list(range(1, 55)), "Stages overlap or omit screens"

    for page in stages["pages"]:
        number, name, group = page["n"], page["file"], page["stage"]
        assert number not in seen_pages, f"Duplicate page {number}"
        seen_pages.add(number)
        assert name not in seen_files, f"Duplicate design {name}"
        seen_files.add(name)
        assert name == "project/" + expected[number - 1], (
            f"Page {number} points to incorrect Claude artboard"
        )
        assert number in step_numbers[group], f"Page {number} belongs to wrong stage"
        assert (design / name).is_file(), f"Missing artboard: {name}"
        refs = re.findall(r"lib/[A-Za-z0-9_/]+\.dart", page["flutter"])
        assert refs, f"No Flutter mapping for page {number}"
        for ref in refs:
            assert (root / ref).is_file(), f"Missing source file {ref} for page {number}"
        assert page["reference"] == "inspeccionada_en_PDF"
        # Never allow "visual verified" to be inferred solely from a code mapping.
        assert page["parity"] in {
            "pendiente_de_captura_real",
            "comparada_con_captura_real",
        }, f"Unknown parity state: page {number}"
    assert len(seen_pages) == 54
    assert "PlusJakartaSans" in (root / "pubspec.yaml").read_text()
    panel = (root / "lib/admin_panel.dart").read_text()
    for expected_guard in ("_previewScopedModules", "adminChannel", "AdminRuntimeScope("):
        assert expected_guard in panel, f"Missing channel guard: {expected_guard}"
    return len(step_numbers), len(seen_pages)


if __name__ == "__main__":
    stages, pages = validate(Path(__file__).resolve().parents[2])
    print(f"PASS: {pages} unique original artboards assigned to {stages} stages.")
    print("NOTE: visual parity remains pending until real screenshots are compared.")
