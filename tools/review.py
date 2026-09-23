#!/usr/bin/env python3
"""Static SkyBandit reviewer. Exit 1 on any BLOCKER."""
from __future__ import annotations

import pathlib
import re
import sys

ROOT = pathlib.Path(__file__).resolve().parents[1]
MOD = ROOT / "modules"

ALLOWED = {
    "modules/shared/Types.luau": set(),
    "modules/shared/GameConfig.luau": {"Types"},
    "modules/shared/Net.luau": {"GameConfig"},
    "modules/server/PlayerData.luau": {"Types", "GameConfig", "ProfileStore"},
    "modules/server/WorldBuilder.luau": {"GameConfig"},
    "modules/server/FlightService.luau": {"GameConfig", "Net"},
    "modules/server/EconomyService.luau": {"Types", "GameConfig", "Net", "PlayerData"},
    "modules/server/PetService.luau": {"Types", "GameConfig", "PlayerData", "EconomyService"},
    "modules/server/HeistService.luau": {
        "Types",
        "GameConfig",
        "Net",
        "PlayerData",
        "FlightService",
        "EconomyService",
        "PetService",
    },
    "modules/server/init.server.luau": {
        "Net",
        "WorldBuilder",
        "PlayerData",
        "FlightService",
        "EconomyService",
        "PetService",
        "HeistService",
        "GameConfig",
        "Types",
    },
    "modules/client/FlightController.luau": {"Types", "GameConfig", "Net"},
    "modules/client/init.client.luau": {"Net", "FlightController"},
}

REQUIRED_NUMBERS = {
    "BaseEggBounty = 250",
    "MinRunSeconds = 8",
    "MaxPayloadEntries = 200",
    "DefaultLimitPerMinute = 60",
    "LiftK = 0.012",
    "DragK = 0.004",
    "StallAirspeed = 40",
    "SnapshotHz = 10",
}

findings: list[str] = []
blockers = 0


def add(sev: str, path: str, line: int, msg: str, fix: str) -> None:
    global blockers
    findings.append(f"[{sev}] {path}:{line} — {msg}\n  Fix: {fix}")
    if sev == "BLOCKER":
        blockers += 1


def rel(p: pathlib.Path) -> str:
    return str(p.relative_to(ROOT)).replace("\\", "/")


def scan_file(path: pathlib.Path) -> None:
    text = path.read_text(encoding="utf-8")
    r = rel(path)
    lines = text.splitlines()
    if not lines or lines[0].strip() != "--!strict":
        add("BLOCKER", r, 1, "--!strict missing", "Put --!strict on line 1")
    for i, line in enumerate(lines, 1):
        if re.search(r"\bTODO\b", line) and not line.strip().startswith("-- Vendored"):
            add("BLOCKER", r, i, "placeholder TODO in accepted code", "Remove TODO or implement")
        if "Instance.new(\"RemoteEvent\")" in line and "Net.luau" not in r:
            add("BLOCKER", r, i, "RemoteEvent created outside Net", "Route through Net wrapper")
        if "Instance.new(\"RemoteFunction\")" in line and "Net.luau" not in r:
            add("BLOCKER", r, i, "RemoteFunction created outside Net", "Route through Net wrapper")
        if re.search(r"\berror\s*\(", line) and "HeistService" in r:
            add("BLOCKER", r, i, "error() reachable from heist remote path", "Return ok, err")
        req = re.search(r"require\((.+)\)", line)
        if req and r in ALLOWED:
            blob = req.group(1)
            names = re.findall(r'["\'](\w+)["\']|WaitForChild\(["\'](\w+)["\']\)|:WaitForChild\(["\'](\w+)["\']\)|Parent\.(\w+)|script\.Parent\.(\w+)', blob)
            flat = {n for tup in names for n in tup if n}
            # also bare require(script.Parent.X)
            bare = re.findall(r"script\.Parent(?:\.Parent)*\.(\w+)", blob)
            flat.update(bare)
            extra = flat - ALLOWED[r] - {"Shared", "Packages", "Parent"}
            # filter service names
            extra -= {"GetService"}
            suspicious = extra & {
                "WorldBuilder",
                "HttpService",
                "Players",
                "HeistService",
                "FlightController",
                "EconomyService",
                "PetService",
                "FlightService",
                "PlayerData",
                "Types",
                "GameConfig",
                "Net",
                "ProfileStore",
            }
            for name in sorted(suspicious):
                if name not in ALLOWED[r]:
                    add("BLOCKER", r, i, f"requires {name} not in brief deps", f"Drop {name} or update brief")


def main() -> int:
    expected = [
        "modules/shared/Types.luau",
        "modules/shared/GameConfig.luau",
        "modules/shared/Net.luau",
        "modules/server/PlayerData.luau",
        "modules/server/WorldBuilder.luau",
        "modules/server/HeistService.luau",
        "modules/server/FlightService.luau",
        "modules/server/EconomyService.luau",
        "modules/server/PetService.luau",
        "modules/client/FlightController.luau",
        "modules/server/init.server.luau",
        "modules/client/init.client.luau",
    ]
    for e in expected:
        p = ROOT / e
        if not p.exists():
            add("BLOCKER", e, 0, "file missing", "Commit the module")
        else:
            scan_file(p)

    cfg = ROOT / "modules/shared/GameConfig.luau"
    if cfg.exists():
        text = cfg.read_text(encoding="utf-8")
        for needle in REQUIRED_NUMBERS:
            if needle not in text:
                add("BLOCKER", "modules/shared/GameConfig.luau", 0, f"missing {needle}", "Restore corrected GameConfig")

    types = ROOT / "modules/shared/Types.luau"
    if types.exists():
        t = types.read_text(encoding="utf-8")
        for shape in ("Rarity", "Mutation", "Pet", "PlayerSave", "FlightState", "CarriedEgg"):
            if f"export type {shape}" not in t:
                add("BLOCKER", "modules/shared/Types.luau", 0, f"missing {shape}", "Restore schema")

    heist = ROOT / "modules/server/HeistService.luau"
    if heist.exists():
        h = heist.read_text(encoding="utf-8")
        if "MinRunSeconds" not in h:
            add("BLOCKER", "modules/server/HeistService.luau", 0, "deliver does not check MinRunSeconds", "Reject instant deliver")
        if "FlightService.getPosition" not in h:
            add("BLOCKER", "modules/server/HeistService.luau", 0, "grab/deliver not using authoritative position", "Use FlightService.getPosition")

    flight = ROOT / "modules/client/FlightController.luau"
    if flight.exists():
        f = flight.read_text(encoding="utf-8")
        if "MaxDt" not in f:
            add("WARN", "modules/client/FlightController.luau", 0, "dt clamp missing", "Clamp to GameConfig.Flight.MaxDt")
        if "SnapshotHz" not in f:
            add("WARN", "modules/client/FlightController.luau", 0, "snapshot rate not from config", "Use SnapshotHz")

    print("SkyBandit static review")
    if not findings:
        print("APPROVED — 0 blockers, 0 warns, 0 nits.")
        return 0
    for item in findings:
        print(item)
    print(f"\n{blockers} BLOCKER(s), {len(findings) - blockers} other.")
    if blockers:
        print("REJECTED")
        return 1
    print("APPROVED with warnings")
    return 0


if __name__ == "__main__":
    sys.exit(main())
