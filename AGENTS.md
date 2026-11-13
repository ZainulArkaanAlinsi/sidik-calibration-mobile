# AGENTS.md — sidik-calibration-mobile (lab app + Sidik Studio)

Agents (Codex, GPT, Claude): read these first, in order.
1. `docs/HANDOFF-CODEX.md` — full handoff (22 Oct 2026): current state, open work, hard rules, lab questions.
2. `CLAUDE.md` — repo conventions.
3. API rules live in the API repo `AGENTS.md` (sidik-calibration-api); they bind mobile work too.

Hard rules (short):
- Never push to `main` directly; PR + green CI. Merging to `main` auto-releases APK and Windows/Studio.
- Releases reach devices via in-app update; never tell the owner to download manually.
- OCR: on-device only, suggestions only, no "accept all", empty cell stays empty. The old digit-character TFLite model/reader was removed (13 Nov 2026). The new TFLite number engine (PP-OCR whole-cell reader, `assets/models/`, `lib/services/ocr_angka/`) sits behind developer switch `PAKAI_MESIN_ANGKA` (old name `PAKAI_MESIN_ANGKA_ONNX` still accepted) and is OFF by default; ML Kit stays the default reader until it is proven on a tablet.
- Do not run emulators on the owner's laptop; one heavy process at a time. Do not commit `pubspec.lock` drift from local SDK.
