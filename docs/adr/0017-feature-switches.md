# 0017. Feature switches keep unfinished features out of a release

- Status: Accepted
- Date: 2026-11-26 (as Azeroth Accord's `Core/Features.lua`, its ADR 0020 update of 2026-11-25)

## Decision

1. `AzerothPrestige/Core/Features.lua` holds one boolean switch per feature that can land before its milestone is complete (for example a category tracker, the network, the leaderboards).
2. While a switch is off nothing of the feature is visible, it registers no event or callback, writes nothing and sends nothing. Modules ask `Features.On(name)` when they act, never once at load.
3. A switch is turned on by the last step of its milestone; the release-preparation step checks that every switch of an unfinished milestone is off. `Tests/test_features.lua` proves both states.

## Consequences

- Positive: steps can ship to `main` continuously without leaking half-finished features into a release.
- Negative: code paths to test with the switch on and off.
