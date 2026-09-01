# Classic Mines Development Contract

## Iteration gate

Each phase must finish in this order:

1. Implement only the phase scope in `docs/ITERATION_PLAN.md`.
2. Run the phase's automated build and tests.
3. Ask an independent sub-agent for adversarial review.
4. Fix every blocking P0/P1 finding.
5. Re-run the full phase test set.
6. Commit and push only after the reviewer returns `PASS`.

## Product constraints

- Native macOS app: Swift 6 language mode, AppKit/Core Graphics, no third-party dependencies.
- Offline: no network, ads, telemetry, accounts, in-app purchases, or remote assets.
- Classic assets are drawn in code; do not copy Microsoft resources or fonts.
- Keep `GameCore` UI-independent and deterministically testable.
- Input feedback must not wait for animation completion.
- Preserve keyboard, VoiceOver, and Reduce Motion behavior.

## Verification

- Source of truth: `docs/DESIGN_PLAN.md` and `docs/STATE_MATRIX.md`.
- Required baseline commands: `swift build` and `swift test`.
- Never claim installation success until the packaged `.app` is launched from `/Applications`.

