#!/usr/bin/env python3
"""judge_bulk.py — apply a verified-name mapping to a plan.json in bulk.
Usage: python3 judge_bulk.py plan.json
Reads MAPPING below; for each "pending" record whose "file" contains a key,
set new_artist/new_name/status. Keys are unique-enough substrings of the
filename. A value of None means SKIP (no verified CJK name).
"""
import json, re, sys
sys.path.insert(0, "/Users/daddy/hermesworkspace/songs_renamer")
import rename_artists as ra

PLAN = "/Volumes/music/#0 Chinese Songs Playlist/Chinese Playlist/# curated/_rename/plan.json"

# filename-substring -> new artist (None = skip)
MAPPING = {
    "A Si - 我在人民广场吃炸鸡": "阿肆",
    "A Si, Yoga Lin": None,  # no single verified CJK name for this duet
    "A-Lin - 天若有情": "黄丽玲",
    "A-Lin - 有一種悲傷": "黄丽玲",
    "A-Lin - 給我一個理由忘記": "黄丽玲",
    "A-Mei Chang": "张惠妹",
    "A-do": "阿杜",
    "Ada Zhuang": "庄心妍",
    "Angela Chang": "张韶涵",
    "Angela Hui": "许靖韵",
    "Ariel Tsai - 卡農 in Love": "蔡佩轩",
    "Ariel Tsai - 小幸運": "蔡佩轩",
    "Aska Yang": "杨宗纬",
    "Cheer Chen": "陈绮贞",
    "Chiang Yu-Heng": "姜育恒",
    "Christine Fan": "范玮琪",
    "Chyi Chin": "齐秦",
    "Cindy Dong": "曾筠芯",
    "Cindy Yen": "袁咏琳",
    "Claire Kuo": "郭静",
    "Crowd Lu": "卢广仲",
    "Da Zhuang - 偽裝": "大壮",
    "Da Zhuang - 我們不一樣": "大壮",
    "Daniel Chan": "陈晓东",
    "Dave Wang": "王杰",
    "Dawen Wang": "王大文",
    "Della": "丁当",
    "Dick and Cowboy": "迪克牛仔",
    "Eason Chan": "陈奕迅",
    "cici - 遗憾也值得": "林恺伦",
}


def main():
    plan = json.load(open(PLAN, encoding="utf-8"))
    changed = 0
    for r in plan:
        if r["status"] != "pending":
            continue
        matched = False
        for sub, artist in MAPPING.items():
            if sub in r["file"]:
                if artist is None:
                    r["status"] = "skip"
                    r["reason"] = "no verified CJK name for this duet/track"
                else:
                    r["new_artist"] = artist
                    r["new_name"] = ra.build_new_name(r["file"], artist, r["title"])
                    r["status"] = "found"
                    r["selected"] = True
                    r["reason"] = "verified CJK name (agent-confirmed)"
                changed += 1
                matched = True
                break
        if not matched:
            print("NOT MATCHED (still pending):", r["file"])
    json.dump(plan, open(PLAN, "w", encoding="utf-8"), ensure_ascii=False, indent=2)
    print(f"judged {changed} pending records -> {PLAN}")
    # report
    from collections import Counter
    print(dict(Counter(r["status"] for r in plan)))
    left = [r["file"] for r in plan if r["status"] == "pending"]
    if left:
        print("STILL PENDING:", *left, sep="\n  ")


if __name__ == "__main__":
    main()
