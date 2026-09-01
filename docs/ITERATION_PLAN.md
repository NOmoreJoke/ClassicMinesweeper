# Iteration Plan

| Phase | Scope | Automated gate | Independent gate |
|---|---|---|---|
| P0 | Repository, build baseline, frozen design/state specifications | `swift build`; `swift test` | Spec/build adversarial review |
| P1 | Board model, SplitMix64, mine generation, reveal, flags, chord, clock/records | Core unit + deterministic regression tests | Correctness/property review |
| P2 | AppKit window, code-drawn pixel UI, counters, face, menus, integer scaling | Build + renderer/layout tests + screenshots | Visual/architecture review |
| P3 | Mouse state machine, keyboard, VoiceOver virtual grid, Reduce Motion | Interaction/accessibility tests | Input/AX adversarial review |
| P4 | App bundle, DMG, ad-hoc signing, checksum, offline/install verification | Package/sign/hash/network checks | Release adversarial review |

No phase advances with unresolved P0/P1 findings.

