---
type: concept
title: Spleeter on Apple Silicon — no arm64 TensorFlow 2.9 wheel
description: Spleeter pins TF 2.9.3 which has no macOS arm64 wheel. On M-series Macs use Demucs instead (pure PyTorch, arm64 wheels, CPU runs fine).
updated: 2026-09-28
---

# Spleeter on Apple Silicon — no arm64 TensorFlow 2.9 wheel

## Fact (verified 2026-09-28 on M4 Mac mini)

`pip/uv install spleeter` fails on macOS arm64:

- Spleeter pins `tensorflow==2.9.3`.
- TF 2.9.3 ships wheels for `manylinux_x86_64`, `macosx_10_14_x86_64`, `win_amd64` only — **no macOS arm64 wheel and no sdist**.
- Resolution result: `error: Distribution tensorflow==2.9.3 ... doesn't have a source distribution or wheel for the current platform`.

Newer TensorFlow (>=2.11) does have arm64 macOS wheels, but Spleeter's pinned 2.9.3 API breaks on TF 2.11+ (known upstream issue; spleeter is effectively unmaintained).

## Decision for StemSplitter

Use **Demucs (`demucs` on PyPI)** instead of Spleeter:

- PyTorch backend — arm64 wheels exist, runs on CPU (a few minutes for a 3–4 min song on M4).
- 4 stems: vocals, drums, bass, other (htdemucs). 6 stems with `htdemucs_6s` (splits guitar/piano into `guitar` + `piano`).
- CLI: `demucs htdemucs -o outdir input.mp3` → writes `htdemucs/<track>/<stem>.wav`.
- Model weights (~100MB) auto-download to `~/.cache/torch/hub` on first run — pre-fetch by running a 1-second tiny clip through it in setup.sh.
- The StemSplitter pipeline is model-agnostic (ffmpeg decode → model → ffmpeg encode MP3 → zip); swapping Spleeter→Demucs only touches `app/main.py`'s `process()` and the STEMS list.

Trade-off vs user's original Spleeter choice: Demucs 4-stem has no dedicated `piano`/`bass`-separated-guitar stems, but `htdemucs_6s` gives vocals/drums/bass/guitar/piano/other and is qualitatively better. User was told Spleeter 5-stems' "piano" stem is artifact-prone anyway.

## Scaffold state (2026-09-28)

Repo at `~/hermesworkspace/stemsplitter` (git, no commits yet — user tests first):

- `pyproject.toml` pinned `requires-python = ">=3.10,<3.11"` (machine has py3.10 via homebrew; 3.11+ unusable for TF). Once we switch to Demucs this pin can be dropped.
- `app/main.py` written around Spleeter's `Separator("5stems")` + `separate()` API — needs a one-function rewrite to `demucs` subprocess/CLI call and STEMS update.
- `setup.sh` still calls the Spleeter model pre-fetch; rewrite to run a tiny demucs inference instead.
- Frontend (index.html/style.css/app.js) and scripts are model-agnostic — no changes needed.

Next step when resuming: confirm with user whether Demucs (htdemucs_6s, 6 stems) is acceptable, rewrite `process()` + STEMS + setup.sh, `uv sync`, then end-to-end test with a short real MP3.
