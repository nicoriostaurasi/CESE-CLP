"""Genera PNG de los VCD mostrando solamente entradas y salidas del top level."""

import re
from pathlib import Path

import matplotlib.pyplot as plt


ROOT = Path(__file__).resolve().parent
WAVEFORMS = ROOT / "waveforms"
OUTPUT = WAVEFORMS / "png"
SOURCES = ROOT.parent / "CLP_CESE" / "CLP_CESE.srcs" / "sources_1" / "new"


def entity_ports(vhdl: Path, entity: str) -> dict[str, str]:
    text = re.sub(r"--.*", "", vhdl.read_text(encoding="utf-8", errors="ignore"))
    match = re.search(rf"\bentity\s+{re.escape(entity)}\s+is\b", text, re.I)
    if not match:
        return {}
    port = re.search(r"\bport\s*\(", text[match.end():], re.I)
    if not port:
        return {}
    start = match.end() + port.end() - 1
    depth = 0
    end = start
    for end in range(start, len(text)):
        if text[end] == "(":
            depth += 1
        elif text[end] == ")":
            depth -= 1
            if depth == 0:
                break
    result = {}
    for declaration in text[start + 1:end].split(";"):
        item = re.match(r"\s*([\w\s,]+)\s*:\s*(in|out|inout|buffer)\b", declaration, re.I)
        if item:
            for name in item.group(1).replace(" ", "").split(","):
                result[name.lower()] = item.group(2).lower()
    return result


def source_for(stem: str) -> Path:
    candidates = {path.stem.lower(): path for path in SOURCES.glob("*.vhd")}
    return candidates[stem.lower()]


def read_vcd(path: Path, ports: dict[str, str]):
    signals = {}
    values = {}
    current_time = 0
    timescale_ps = 1
    top_scope = path.stem.lower()
    scope = []
    definitions = True

    for raw in path.read_text(encoding="utf-8", errors="ignore").splitlines():
        line = raw.strip()
        if definitions:
            if line.startswith("$timescale"):
                continue
            if line.startswith("$scope"):
                scope.append(line.split()[2].lower())
            elif line.startswith("$upscope"):
                if scope:
                    scope.pop()
            elif line.startswith("$var") and scope and scope[-1] == top_scope:
                fields = line.split()
                width, identifier, name = int(fields[2]), fields[3], fields[4]
                base_name = name.split("[")[0].lower()
                if base_name in ports:
                    signals[identifier] = (name, width, ports[base_name])
                    values[identifier] = []
            elif line.startswith("$enddefinitions"):
                definitions = False
            continue

        if line.startswith("#"):
            current_time = int(line[1:])
        elif line and line[0] in "01xXzZuU" and line[1:] in signals:
            values[line[1:]].append((current_time, line[0].upper()))
        elif line.startswith(("b", "B")):
            value, identifier = line[1:].split()
            if identifier in signals:
                values[identifier].append((current_time, value.upper()))

    return signals, values, current_time * timescale_ps / 1000.0


def bus_label(value: str) -> str:
    if any(bit not in "01" for bit in value):
        return "X"
    return f"0x{int(value, 2):X}"


def draw(vcd: Path):
    ports = entity_ports(source_for(vcd.stem), vcd.stem)
    signals, changes, end_ns = read_vcd(vcd, ports)
    ordered = list(signals.items())
    height = max(3.0, 0.75 * len(ordered) + 1.2)
    fig, axis = plt.subplots(figsize=(16, height))

    for row, (identifier, (name, width, direction)) in enumerate(reversed(ordered)):
        events = changes[identifier]
        if not events:
            continue
        base = row
        if width == 1:
            for index, (start, value) in enumerate(events):
                finish = events[index + 1][0] if index + 1 < len(events) else end_ns * 1000
                y = base + (0.28 if value == "1" else -0.28 if value == "0" else 0)
                axis.hlines(y, start / 1000, finish / 1000,
                            color="#20c55a" if value in "01" else "#e34b4b", linewidth=2)
                if index + 1 < len(events):
                    next_value = events[index + 1][1]
                    next_y = base + (0.28 if next_value == "1" else -0.28 if next_value == "0" else 0)
                    axis.vlines(finish / 1000, min(y, next_y), max(y, next_y), color="#20c55a", linewidth=1)
        else:
            for index, (start, value) in enumerate(events):
                finish = events[index + 1][0] if index + 1 < len(events) else end_ns * 1000
                axis.hlines(base, start / 1000, finish / 1000, color="#35a7ff", linewidth=2)
                if finish > start:
                    axis.text((start + finish) / 2000, base + 0.12, bus_label(value),
                              ha="center", va="bottom", fontsize=8, color="#d7ecff")

    labels = [f"{name}  ({direction})" for _, (name, _, direction) in reversed(ordered)]
    axis.set_yticks(range(len(labels)), labels)
    axis.set_xlim(0, end_ns)
    axis.set_ylim(-0.6, max(len(labels) - 0.4, 0.6))
    axis.set_xlabel("Tiempo [ns]")
    axis.set_title(vcd.stem)
    axis.grid(axis="x", color="#555555", alpha=0.45)
    axis.set_facecolor("#16191d")
    fig.patch.set_facecolor("#202328")
    axis.tick_params(colors="white")
    axis.xaxis.label.set_color("white")
    axis.yaxis.label.set_color("white")
    axis.title.set_color("white")
    for spine in axis.spines.values():
        spine.set_color("#777777")
    fig.tight_layout()
    OUTPUT.mkdir(parents=True, exist_ok=True)
    fig.savefig(OUTPUT / f"{vcd.stem}.png", dpi=160, facecolor=fig.get_facecolor())
    plt.close(fig)


def main():
    files = sorted(WAVEFORMS.glob("*.vcd"))
    generated = 0
    for vcd in files:
        if (OUTPUT / f"{vcd.stem}.png").exists():
            continue
        draw(vcd)
        generated += 1
        print(f"OK: {vcd.stem}.png")
    print(f"Disponibles {len(files)} PNG ({generated} nuevos) en {OUTPUT}")


if __name__ == "__main__":
    main()
