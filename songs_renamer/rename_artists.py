#!/usr/bin/env python3
"""songs_renamer — rename "artist - title.mp3" artist names to Simplified Chinese.

Subcommands:
  plan   FOLDER          Parse + search every *.mp3 in FOLDER, write plan.json
  apply  [plan.json]     Apply selected renames from a plan file (default plan.json)

The plan file is the checkpoint: it records, per file, whether a rename was
found (with source + confidence) or skipped (with reason), plus a "selected"
flag you tick before applying.
"""

import json
import os
import re
import subprocess
import sys
import time

# ---------------------------------------------------------------- parsing ---

# Split "artist - title.mp3" on the FIRST " - " (hyphen with spaces) only.
SPLIT = re.compile(r"^(.*)\s+-\s+(.*)$")


def parse_filename(stem: str):
    """Return (artist, title) or (None, None) if the name has no ' - ' split."""
    m = SPLIT.match(stem)
    if not m:
        return None, None
    artist = m.group(1).strip()
    title = m.group(2).strip()
    return artist, title


def normalize_artist(artist: str) -> str:
    """& -> comma, no spaces around commas, drop leading articles, keep order."""
    a = artist.replace("&", ",")
    a = re.sub(r"\s*,\s*", ",", a)
    parts = [p.strip() for p in a.split(",") if p.strip()]
    out = []
    for p in parts:
        m = re.match(r"^(?:The|A|An)\s+(?=[\w])", p, re.I)
        if m:
            p = p[m.end():].lstrip()
        out.append(p)
    return ",".join(out)


def build_new_name(old_file: str, new_artist: str, title: str) -> str:
    """Assemble the target filename. new_artist should already be in the
    desired form (Simplified CJK for a verified rename, or the cleaned-up
    ASCII form for a &-normalization-only rename)."""
    return f"{new_artist} - {title}.mp3"


# --------------------------------------------------------------- searching --

def ddgs_text(query: str, max_results: int = 8, region: str = "tw-tw"):
    """Run a DuckDuckGo text search via the ddgs CLI (auto backend).
    Returns a list of {title, href, body} dicts.
    This ddgs build only writes JSON to a *file* (-o path) — it does not
    stream JSON to stdout — so we write to a temp file and read it back."""
    import tempfile
    with tempfile.NamedTemporaryFile(suffix=".json", delete=False) as tf:
        tmp = tf.name
    cmd = [
        "ddgs", "text", "-q", query,
        "-m", str(max_results),
        "-r", region,
        "-o", tmp,
    ]
    try:
        out = subprocess.run(cmd, capture_output=True, text=True, timeout=90)
    except subprocess.TimeoutExpired:
        return []
    if not os.path.exists(tmp):
        return []
    try:
        with open(tmp, encoding="utf-8") as fh:
            data = json.load(fh)
    except (json.JSONDecodeError, OSError):
        return []
    finally:
        os.unlink(tmp)
    if isinstance(data, dict):
        data = data.get("results", [])
    results = []
    for r in data:
        href = r.get("href") or r.get("url", "")
        if not href:
            continue
        results.append({
            "title": r.get("title", ""),
            "href": href,
            "body": r.get("body", "") or r.get("description", ""),
        })
    return results


# ----------------------------------------------------------- source ranking -

# Ranked most-accurate to least (used to pick which source "verifies" a name).
#   1 wikipedia (zh/en) — canonical
#   2 official MV (youtube/bilibili)
#   3 music platforms (kkbox/joox/netease/qmusic)
#   4 lyrics sites (mulanci/moe/lyrics)
#   5 generic web
SOURCE_RANK = [
    (1, "wikipedia"),
    (2, "official_mv"),
    (3, "music_platform"),
    (4, "lyrics_site"),
    (5, "web"),
]


def classify_source(href: str) -> int:
    """Map a result URL to its accuracy rank (lower = more authoritative)."""
    u = href.lower()
    if "wikipedia.org" in u:
        return 1
    if "youtube.com" in u or "bilibili.com" in u or "youtu.be" in u:
        return 2
    if any(p in u for p in ("kkbox.com", "joox", "music.163.com", "netease",
                            "y.qq.com", "qmusic", "genie", "spotify.com")):
        return 3
    if any(p in u for p in ("mulanci.org", "moe.moe", "lyrics.com", "azlyrics",
                            "moemoe.tw")):
        return 4
    return 5


def cjk_chars(s: str) -> int:
    """Count CJK ideographs in a string."""
    return sum(1 for c in s if '\u4e00' <= c <= '\u9fff')


# ---------------------------------------------------------- plan building ----

def build_plan(folder: str, out_path: str):
    files = sorted(
        f for f in os.listdir(folder) if f.lower().endswith(".mp3")
    )
    plan = []

    # Checkpoint: resume from a partial plan.json if present (same folder,
    # same file list, no pending left already searched).
    if os.path.exists(out_path):
        try:
            prev = json.load(open(out_path, encoding="utf-8"))
            prev_done = {r["file"] for r in prev if r["status"] != "pending"}
            if len(prev) == len(files) and prev_done:
                plan = prev
                files = [r["file"] for r in plan if r["status"] == "pending"]
                print(f"resuming: {len(files)} pending of {len(plan)} records")
        except (json.JSONDecodeError, OSError, KeyError):
            pass

    for fn in files:
        if any(r["file"] == fn and r["status"] != "pending" for r in plan):
            continue  # already judged
        stem, ext = os.path.splitext(fn)
        artist, title = parse_filename(stem)
        rec = {
            "file": fn,
            "artist": artist,
            "title": title,
            "parse_ok": artist is not None,
            "status": None,      # "found" | "skip" | "unparseable"
            "new_artist": None,
            "new_name": None,
            "reason": None,
            "sources": [],       # [rank, url, snippet]
            "selected": False,
        }
        if not rec["parse_ok"]:
            rec["status"] = "unparseable"
            rec["reason"] = "filename has no ' - ' separator"
            plan.append(rec)
            _checkpoint(plan, out_path)
            continue

        # Search: prefer a query that fuses the CJK title (strong signal for a
        # Chinese song) with the artist as written.
        queries = []
        if cjk_chars(title) >= 2:
            queries.append(f"{title} {artist}")
        queries.append(f"{artist} 歌手 中文名")
        all_res = []
        for q in queries:
            for r in ddgs_text(q, max_results=8):
                if r["href"] not in [x["href"] for x in all_res]:
                    all_res.append(r)
            time.sleep(0.6)

        # Classify + record every result (ranked) for the agent to judge.
        scored = sorted(
            (
                {"rank": classify_source(r["href"]), "url": r["href"],
                 "title": r.get("title", "")[:120],
                 "body": (r.get("body") or "")[:300]}
                for r in all_res
            ),
            key=lambda x: x["rank"],
        )
        rec["sources"] = scored

        # Heuristic gate: is this plausibly a Chinese-language song?
        # (title is non-None here — parse failed paths already returned.)
        has_cjk_title = cjk_chars(title) >= 1
        top_cjk_in_results = any(
            cjk_chars((x["title"] or "") + " " + (x["body"] or "")) >= 2
            for x in scored[:6]
        )
        if not (has_cjk_title and top_cjk_in_results):
            rec["status"] = "skip"
            rec["reason"] = ("not a verified Chinese-language song "
                             "(skip per Q8)")
        else:
            # CJK title present + CJK in top results => Chinese song, but the
            # actual name + verification call is made by the agent reading the
            # sources below. Mark "pending" so the agent fills new_artist.
            rec["status"] = "pending"
            rec["reason"] = ("Chinese song; agent to verify CJK artist name "
                             "from sources (1 authoritative OR 2+ agreeing; "
                             "else skip)")
        plan.append(rec)
        _checkpoint(plan, out_path)

    n = len(plan)
    print(f"plan: {n} files in {folder} -> {out_path}")
    for r in plan:
        print(f"  [{r['status']:>11}] {r['file']}")


def _checkpoint(plan, out_path):
    """Write plan.json after every record so an interrupted run resumes."""
    with open(out_path, "w", encoding="utf-8") as fh:
        json.dump(plan, fh, ensure_ascii=False, indent=2)


def main():
    if len(sys.argv) < 2:
        print(__doc__)
        sys.exit(1)
    cmd = sys.argv[1]
    if cmd == "plan":
        folder = sys.argv[2] if len(sys.argv) > 2 else "."
        # Default plan path: next to the source files, inside the folder.
        out = sys.argv[3] if len(sys.argv) > 3 else os.path.join(folder, "plan.json")
        out = os.path.abspath(out)
        build_plan(os.path.abspath(folder), out)
    elif cmd == "apply":
        p = sys.argv[2] if len(sys.argv) > 2 else "plan.json"
        apply_plan(os.path.abspath(p))
    else:
        print(__doc__)
        sys.exit(1)


# ------------------------------------------------------------ applying -------

def apply_plan(plan_path: str):
    folder = os.path.dirname(plan_path)
    with open(plan_path, encoding="utf-8") as fh:
        plan = json.load(fh)
    done, err = 0, []
    for r in plan:
        if not r.get("selected") or r.get("status") != "found":
            continue
        s = os.path.join(folder, r["file"])
        dst = r["new_name"]
        if not os.path.exists(s):
            err.append(f"missing source: {r['file']}")
            continue
        if os.path.exists(os.path.join(folder, dst)):
            err.append(f"target exists, skipping: {dst}")
            continue
        os.rename(s, os.path.join(folder, dst))
        done += 1
        print(f"renamed: {r['file']} -> {dst}")
    if err:
        print("errors:", *err, sep="\n  ")
    print(f"applied {done} rename(s) in {folder}")


if __name__ == "__main__":
    main()

