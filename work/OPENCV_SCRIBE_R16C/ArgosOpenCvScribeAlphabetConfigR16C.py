#!/usr/bin/env python3
"""Apply a hash-locked configured scribe alphabet to a provider-local R11 module."""

from __future__ import annotations

import hashlib
import json
from pathlib import Path
from typing import Any


SCHEMA = "argos_opencv_scribe_character_alphabet_v1"
FULL_ALPHABET = "0123456789ABCDEFGHIJKLMNOPQRSTUVWXYZ"


def sha256_file(path: Path) -> str:
    digest = hashlib.sha256()
    with path.open("rb") as stream:
        for block in iter(lambda: stream.read(4 * 1024 * 1024), b""):
            digest.update(block)
    return digest.hexdigest().upper()


def configure(r11: Any, path: Path, expected_sha256: str) -> dict[str, Any]:
    actual = sha256_file(path)
    if actual != expected_sha256.upper():
        raise ValueError("Character-alphabet configuration SHA-256 mismatch.")
    with path.open("r", encoding="utf-8-sig") as stream:
        config = json.load(stream)
    if not isinstance(config, dict) or config.get("schema") != SCHEMA:
        raise ValueError("Character-alphabet configuration schema mismatch.")
    for key in ("activationAuthorized", "identityAdmissionAuthorized", "trainingAuthorized", "productionAuthorized"):
        if config.get(key) is not False:
            raise ValueError(f"Character-alphabet authority mismatch: {key}")
    allowed = str(config.get("configuredBodyLabels", ""))
    excluded = str(config.get("excludedBodyLabels", ""))
    if len(set(allowed)) != len(allowed) or len(set(excluded)) != len(excluded):
        raise ValueError("Character-alphabet labels are duplicated.")
    if set(allowed) & set(excluded) or set(allowed + excluded) != set(FULL_ALPHABET):
        raise ValueError("Configured and excluded labels do not partition the full alphabet.")
    if r11.BODY_LABELS != FULL_ALPHABET:
        raise ValueError("Provider body alphabet changed before configuration.")
    r11.BODY_LABELS = allowed
    return {
        "configurationSha256": actual,
        "configuredBodyLabels": allowed,
        "excludedBodyLabels": excluded,
        "formatRuleIndependentlyConfirmed": config.get("formatRuleIndependentlyConfirmed") is True,
        "activationAuthorized": False,
        "identityAdmissionAuthorized": False
    }
