#!/usr/bin/env python3
"""judge_plan.py — fill in new_artist / new_name for "pending" records in a
plan.json, based on a mapping you provide, and flip them to "found".

Usage:
  python3 judge_plan.py plan.json "file_substr|new_artist" ["..." ...]

If a record's "file" contains file_substr, set new_artist + new_name + status.
Records left "pending" after this run remain pending (you should either add a
mapping or manually mark them "skip").
"""
import json, sys, re
import importlib.util

spec = importlib.util.spec_from_file_location(
    "ra", "/Users/daddy/hermesworkspace/songs_renamer/rename_artists.py")
ra = importlib.util.module_from_spec(spec)
spec.loader.exec_module(ra)


def main():
    plan_path = sys.argv[1]
    plan = json.load(open(plan_path, encoding="utf-8"))
    mapping = {}
    for arg in sys.argv[2:]:
        if "|" in arg:
            sub, artist = arg.split("|", 1)
            mapping[sub] = artist
        else:
            mapping[arg] = None  # "arg" with no "|" means SKIP
    changed = 0
    for r in plan:
        if r["status"] != "pending":
            continue
        for sub, artist in mapping.items():
            if sub in r["file"]:
                if artist is None:
                    r["status"] = "skip"
                    r["reason"] = "no verified CJK artist name (skip per rule)"
                else:
                    r["new_artist"] = artist
                    r["new_name"] = ra.build_new_name(r["file"], artist, r["title"])
                    r["status"] = "found"
                    r["selected"] = True
                    r["reason"] = "verified CJK name (agent-confirmed)"
                changed += 1
                break
    json.dump(plan, open(plan_path, "w", encoding="utf-8"),
              ensure_ascii=False, indent=2)
    print(f"judged {changed} pending -> found in {plan_path}")
    still = [r["file"] for r in plan if r["status"] == "pending"]
    if still:
        print("STILL PENDING:", *still, sep="\n  ")


if __name__ == "__main__":
    main()
