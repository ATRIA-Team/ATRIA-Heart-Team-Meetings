<!--
  Title format: [Type] Short description
  Types: [Feature] · [Fix] · [Refactor] · [Docs] · [Test]
  One PR = one feature or one fix. See CONTRIBUTING.md for full guidelines.
-->

## What does this PR do?

<!-- One paragraph describing the change and why it is needed. -->

## How was it tested?

<!-- Describe how you verified the change. If it requires a real Apple Vision Pro, say so. -->

- [ ] Tested on a real Apple Vision Pro
- [ ] Tested in the visionOS simulator
- [ ] Tested on macOS (`ATRIAmac`)
- [ ] Unit tests only

## Are there any known limitations or follow-ups?

<!-- List anything deliberately left out of scope, or write "None". -->

## Checklist

- [ ] Branch is up to date with `develop` (`git pull --rebase origin develop`)
- [ ] The app builds without warnings on both `ATRIA` (visionOS) and `ATRIAmac` (macOS) schemes
- [ ] All existing tests pass (`xcodebuild test` — see [Testing](../README.md#testing))
- [ ] New store logic has unit tests in `ATRIATests/`
- [ ] No pixel data, credentials, or patient data are included in any commit
- [ ] If a new SharePlay message type was added, `DICOMSyncMessage.Kind`, `SessionStore.applyMessage(_:)`, and `SharePlayCoordinator.apply(_:from:)` are all updated consistently
- [ ] Debug flags (e.g. `bypassSharePlay`) are set back to `false`
- [ ] Screenshots or a short screen recording are attached if the change affects any UI
