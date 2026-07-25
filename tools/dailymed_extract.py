#!/usr/bin/env python3
"""Build medication_rules.json from DailyMed SPL labels. Offline, run once.

This script is never deployed and never runs on a phone. CLAUDE.md §3: the demo
must not depend on a third-party API being reachable, so the timing rules are
extracted here, checked by a human, and shipped as a static file in the bundle.

What it does, per medication:

    name -> RxNorm RxCUI -> DailyMed SPL -> "Dosage and Administration"
    (LOINC 34068-7) -> timing rules, each keeping the exact source sentence
    and the setid it came from.

Two things it deliberately does NOT do:

  * It never writes a rule it cannot quote. Every rule carries the sentence it
    was read out of, so anything shown in the app can be traced to a real label
    rather than to a regex someone wrote at 1am.
  * It never invents a mapping. The seeded medications are UK (Co-careldopa,
    Adcal-D3) and DailyMed is US FDA, so where a UK product has a US
    equivalent it is named explicitly in MEDICATIONS below with a reason.
    Where none exists, the medication is written out with an empty rule list
    and an `unresolved` note. An honest gap beats a plausible invention —
    that is rule 2 of the extraction contract applied to ourselves.

Usage:
    python3 tools/dailymed_extract.py                     # writes the JSON
    python3 tools/dailymed_extract.py --print             # also dumps sections

Read the output before committing it. That review is not optional.
"""

from __future__ import annotations

import argparse
import json
import re
import sys
import time
import urllib.parse
import urllib.request
import xml.etree.ElementTree as ET
from pathlib import Path

RXNAV = "https://rxnav.nlm.nih.gov/REST"
DAILYMED = "https://dailymed.nlm.nih.gov/dailymed/services/v2"
HL7 = "urn:hl7-org:v3"
DOSAGE_AND_ADMINISTRATION = "34068-7"

OUTPUT = Path(__file__).resolve().parents[1] / "CareAid" / "Services" / "Rules" / "medication_rules.json"


# The eight seeded medications, in the exact `medication.name` spelling from
# 002_seed.sql. `query` is what RxNorm is asked for; where it differs from the
# name, `mapping_note` says why, because a US label standing in for a UK
# product is an interpretation and should be visible as one.
MEDICATIONS = [
    {
        "name": "Co-careldopa (Sinemet)",
        "query": "carbidopa / levodopa",
        "mapping_note": "UK co-careldopa is the same combination as US carbidopa/levodopa (Sinemet).",
    },
    {"name": "Entacapone", "query": "entacapone"},
    {"name": "Rasagiline", "query": "rasagiline"},
    {"name": "Apixaban", "query": "apixaban"},
    {"name": "Bisoprolol", "query": "bisoprolol fumarate"},
    {"name": "Atorvastatin", "query": "atorvastatin"},
    {"name": "Levothyroxine", "query": "levothyroxine"},
    {
        "name": "Adcal-D3",
        "query": "calcium carbonate / cholecalciferol",
        "mapping_note": "Adcal-D3 is a UK brand with no single US SPL; queried as its two ingredients.",
    },
]


# Each pattern reads one kind of timing instruction. `hours` is pulled from the
# sentence when the pattern captures it, never assumed.
RULE_PATTERNS = [
    (
        "empty_stomach",
        re.compile(
            r"\bempty stomach\b|\bbefore (?:breakfast|the first meal|food)\b"
            r"|\b(?:one[- ]half to one|1/2 to 1|30 to 60 minutes?) (?:hour |hours )?before breakfast\b",
            re.I,
        ),
    ),
    (
        "with_food",
        re.compile(r"\bwith (?:food|a meal|meals)\b|\bafter (?:a meal|meals|eating)\b", re.I),
    ),
    (
        "separation",
        re.compile(
            r"\bat least\s+(?P<hours>\d+(?:\.\d+)?)\s*hours?\s+(?:before or after|apart|after|before)\b"
            r"|\bseparate\D{0,30}?by\s+(?P<hours2>\d+(?:\.\d+)?)\s*hours?\b",
            re.I,
        ),
    ),
    (
        "avoid_protein",
        re.compile(r"\bhigh[- ]protein\b|\bprotein[- ]rich\b|\b(?:dietary )?protein\b.{0,60}\babsorption\b", re.I),
    ),
    (
        "same_time_daily",
        re.compile(r"\b(?:at (?:about )?the same time|same time each day|same time every day)\b", re.I),
    ),
    (
        "with_water",
        re.compile(r"\bwith\s+(?:a\s+)?(?:full\s+)?glass(?:ful)?\s+of\s+water\b", re.I),
    ),
    # Entacapone is the reason this exists: its whole schedule is "whenever the
    # levodopa dose is", which the scheduler has to honour as a hard tie rather
    # than treat as a free-floating time.
    (
        "co_administer",
        re.compile(
            r"\b(?:concomitantly|together|in association)\s+with\s+each\b"
            r"|\bwith\s+each\s+(?P<partner>[a-z][a-z\- ]{2,40}?)\s+dose\b",
            re.I,
        ),
    ),
    # Explicitly unconstrained. Worth recording: it tells the scheduler this one
    # can be moved to wherever it suits her, which is the whole point of C12.
    (
        "food_optional",
        re.compile(r"\bwith or without food\b|\bwithout regard to (?:food|meals)\b", re.I),
    ),
]

# A "Dosage and Administration" section this short is a bare ingredient list or
# a stub, not instructions. Treat it as missing rather than as "no rules".
MINIMUM_SECTION_LENGTH = 200

# Sentences that merely name a section or cross-reference one carry no
# instruction and would otherwise quote as nonsense.
NOISE = re.compile(r"^\s*(?:\d+(?:\.\d+)*\s*)?(?:see|refer to|full prescribing information)\b", re.I)


def fetch(url: str, retries: int = 3) -> bytes:
    """GET with a couple of retries. These are public NIH endpoints; be polite."""
    last = None
    for attempt in range(retries):
        try:
            request = urllib.request.Request(url, headers={"User-Agent": "CareAid-hackathon/1.0"})
            with urllib.request.urlopen(request, timeout=45) as response:
                return response.read()
        except Exception as error:  # noqa: BLE001 - report and move on
            last = error
            time.sleep(1.5 * (attempt + 1))
    raise RuntimeError(f"{url} failed after {retries} attempts: {last}")


def resolve_rxcui(query: str) -> str | None:
    """RxNorm's own normaliser — approximate match is deliberately not used."""
    url = f"{RXNAV}/rxcui.json?name={urllib.parse.quote(query)}&search=2"
    data = json.loads(fetch(url))
    ids = data.get("idGroup", {}).get("rxnormId") or []
    return ids[0] if ids else None


def find_label(rxcui: str) -> dict | None:
    """Pick one SPL for an RxCUI.

    Prefers an oral solid human-prescription label: those carry the
    administration instructions we care about, where an injection or a
    repackager's minimal label often does not.
    """
    url = f"{DAILYMED}/spls.json?rxcui={rxcui}&pagesize=50"
    entries = json.loads(fetch(url)).get("data") or []
    if not entries:
        return None

    def score(entry: dict) -> tuple:
        title = (entry.get("title") or "").upper()
        oral = any(word in title for word in ("TABLET", "CAPSULE", "ORAL"))
        parenteral = any(word in title for word in ("INJECTION", "INTRAVENOUS", "LYOPHILIZED"))
        # Immediate release, unless the seed says otherwise: Margaret is on
        # 25/100mg four times a day, which is the IR product. The ER label
        # describes a different medicine and its timing rules are not hers.
        modified = any(
            word in title
            for word in ("EXTENDED RELEASE", "EXTENDED-RELEASE", "DELAYED", "DISINTEGRATING")
        )
        return (oral, not parenteral, not modified, entry.get("spl_version") or 0)

    return sorted(entries, key=score, reverse=True)[0]


def dosage_section(setid: str) -> str | None:
    """The Dosage and Administration section of an SPL, as flat text."""
    xml = fetch(f"{DAILYMED}/spls/{setid}.xml")
    root = ET.fromstring(xml)
    for section in root.iter(f"{{{HL7}}}section"):
        code = section.find(f"{{{HL7}}}code")
        if code is not None and code.get("code") == DOSAGE_AND_ADMINISTRATION:
            return " ".join("".join(section.itertext()).split())
    return None


def sentences(text: str) -> list[str]:
    """Split into quotable sentences.

    Labels are bullet lists as often as prose, and the bullets frequently run
    straight on from the previous full stop with no space ("...food (2.1).•
    Assess LDL-C..."). Without normalising those first the whole section reads
    as one enormous sentence and every rule in it is skipped as too long to
    quote.
    """
    text = re.sub(r"[•●▪·]+", " . ", text)
    parts = re.split(r"(?<=[.;])\s*(?=[A-Z(o])", text)
    cleaned = []
    for part in parts:
        part = tidy(part)
        if part:
            cleaned.append(part)
    return cleaned


def tidy(sentence: str) -> str:
    """Make a sentence quotable.

    These strings end up on screen as the citation behind a rule, so they have
    to read like something off a label rather than like scraper output: no
    glued-on section heading, no leading "(2.1)" cross-reference, no stray full
    stop left behind by a bullet.
    """
    sentence = " ".join(sentence.split())
    sentence = re.sub(r"^\d*\s*DOSAGE\s*(?:AND|&)\s*ADMINISTRATION\s*", "", sentence, flags=re.I)
    sentence = re.sub(r"^\(\d+(?:\.\d+)*\)\s*", "", sentence)
    sentence = sentence.lstrip(". ").strip()
    sentence = re.sub(r"\s+\.\s*$", "", sentence)
    return sentence


def extract_rules(text: str) -> list[dict]:
    """Every rule keeps the sentence it came from. No sentence, no rule."""
    found: dict[str, dict] = {}

    for sentence in sentences(text):
        if NOISE.match(sentence) or len(sentence) > 400:
            continue
        for kind, pattern in RULE_PATTERNS:
            match = pattern.search(sentence)
            if not match:
                continue
            rule = {"type": kind, "source_sentence": sentence}
            groups = match.groupdict()
            hours = groups.get("hours") or groups.get("hours2")
            if hours:
                rule["hours"] = float(hours)
            # First mention wins: labels restate the same instruction in the
            # highlights and again in full, and the first is the tighter phrasing.
            found.setdefault(kind, rule)

    return list(found.values())


def build(verbose: bool) -> dict:
    entries = []
    for medication in MEDICATIONS:
        name, query = medication["name"], medication["query"]
        print(f"— {name}  (rxnorm: {query})", file=sys.stderr)

        entry: dict = {"name": name, "query": query, "rules": []}
        if medication.get("mapping_note"):
            entry["mapping_note"] = medication["mapping_note"]

        try:
            rxcui = resolve_rxcui(query)
            if not rxcui:
                entry["unresolved"] = f"RxNorm has no exact match for {query!r}."
                entries.append(entry)
                print("   unresolved: no RxCUI", file=sys.stderr)
                continue
            entry["rxcui"] = rxcui

            label = find_label(rxcui)
            if not label:
                entry["unresolved"] = f"No DailyMed SPL is published for RxCUI {rxcui}."
                entries.append(entry)
                print("   unresolved: no SPL", file=sys.stderr)
                continue
            entry["setid"] = label["setid"]
            entry["spl_title"] = label.get("title")

            text = dosage_section(label["setid"])
            if not text:
                entry["unresolved"] = "SPL has no Dosage and Administration section."
                entries.append(entry)
                print("   unresolved: no dosage section", file=sys.stderr)
                continue
            if len(text) < MINIMUM_SECTION_LENGTH:
                entry["unresolved"] = (
                    "SPL's Dosage and Administration section is an ingredient list, "
                    "not administration instructions."
                )
                entries.append(entry)
                print("   unresolved: section is a stub", file=sys.stderr)
                continue

            if verbose:
                print(f"   section: {text[:600]}", file=sys.stderr)

            entry["rules"] = extract_rules(text)
            print(f"   {len(entry['rules'])} rule(s): "
                  f"{', '.join(r['type'] for r in entry['rules']) or '—'}", file=sys.stderr)

        except Exception as error:  # noqa: BLE001 - one failure must not lose the rest
            entry["unresolved"] = f"Lookup failed: {error}"
            print(f"   failed: {error}", file=sys.stderr)

        entries.append(entry)

    return {
        "generated_by": "tools/dailymed_extract.py",
        "source": "DailyMed SPL v2, Dosage and Administration (LOINC 34068-7), via RxNorm",
        "disclaimer": (
            "Reference data only. These are label administration facts, not advice, "
            "not a diagnosis and not a treatment recommendation. A timing conflict "
            "produces a question for a pharmacist or GP, never a schedule change."
        ),
        "medications": entries,
    }


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--print", dest="verbose", action="store_true",
                        help="dump each Dosage and Administration section")
    parser.add_argument("--out", type=Path, default=OUTPUT)
    args = parser.parse_args()

    document = build(args.verbose)
    args.out.parent.mkdir(parents=True, exist_ok=True)
    args.out.write_text(json.dumps(document, indent=2, ensure_ascii=False) + "\n")

    resolved = sum(1 for m in document["medications"] if m["rules"])
    print(f"\nWrote {args.out}", file=sys.stderr)
    print(f"{resolved}/{len(document['medications'])} medications have rules. "
          f"Read the file before committing it.", file=sys.stderr)
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
