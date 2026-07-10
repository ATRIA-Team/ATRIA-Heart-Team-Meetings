# Contributing to ATRIA

We welcome contributions from collaborators and researchers. Please follow the guidelines below to keep the codebase clean and the review process efficient.

## Getting set up

1. Fork and clone the repository, then open `ATRIA.xcodeproj` in Xcode 26 or later.
2. Select the **ATRIA** scheme (visionOS) or **ATRIAmac** (macOS companion). Xcode resolves the remote package dependencies ([DICOM-Decoder](https://github.com/ATRIA-Team/DICOM-Decoder), [iCloudFolderSync](https://github.com/ATRIA-Team/iCloudFolderSync)) automatically on first open.
3. Read the [Architecture](README.md#architecture) section of the README before making changes — the app follows an MV + domain-stores pattern, and contributions are expected to follow it too.

**Note:** SharePlay features require a real Apple Vision Pro. For UI work on a single device or in the simulator, use the `bypassSharePlay` debug flag (see [Debug Flags](README.md#debug-flags)) — and always set it back to `false` before committing.

## Reporting bugs and requesting features

Open a [GitHub issue](https://github.com/ATRIA-Team/ATRIA-Heart-Team-Meetings/issues). For bugs, include:

- What you did, what you expected, and what happened instead
- Whether it occurred on a real Apple Vision Pro or in the simulator
- Whether a SharePlay session was active

**Never attach real patient data to an issue.** Use anonymized or synthetic DICOM files only.

## Branch strategy

```
main        ← stable, production-ready code
  └── develop       ← integration branch, all PRs merge here first
        └── feature/your-feature-name   ← your work
        └── fix/short-description-of-bug
        └── docs/what-you-documented
```

- **Never push directly to `main` or `develop`.**
- Always branch off `develop` and open your PR back into `develop`.
- Use lowercase and hyphens: `feature/annotation-export`, `fix/slice-sync-crash`.

## Opening a Pull Request

**1. Keep it focused**
One PR = one feature or one fix. If you find yourself writing "and also…" in the description, split it into two PRs.

**2. Write a clear title**
Use the format: `[Type] Short description` — e.g.:

| Type | When to use |
|---|---|
| `[Feature]` | New capability added |
| `[Fix]` | Bug corrected |
| `[Refactor]` | Code restructured with no behavior change |
| `[Docs]` | Documentation only |
| `[Test]` | Tests added or updated |

**3. Fill in the PR description**
Every PR must answer these three questions:

- **What does this PR do?** — one paragraph describing the change and why it is needed.
- **How was it tested?** — describe how you verified the change. If it requires a real device, say so.
- **Are there any known limitations or follow-ups?** — list anything deliberately left out of scope.

**4. Use the checklist**
Before marking the PR as ready for review, confirm:

- [ ] Branch is up to date with `develop` (`git pull --rebase origin develop`)
- [ ] The app builds without warnings on both `ATRIA` (visionOS) and `ATRIAmac` (macOS) schemes
- [ ] All existing tests pass (`xcodebuild test` — see [Testing](README.md#testing) in the README)
- [ ] New store logic has unit tests in `ATRIATests/`
- [ ] No pixel data, credentials, or patient data are included in any commit
- [ ] If a new SharePlay message type was added, `DICOMSyncMessage.Kind`, `SessionStore.applyMessage(_:)`, and `SharePlayCoordinator.apply(_:from:)` are all updated consistently
- [ ] Screenshots or a short screen recording are attached if the change affects any UI

**5. Request a review**
Assign at least one reviewer before marking the PR ready. Do not merge your own PR.

## Commit messages

Write short, imperative commit messages that describe *what* changed:

```
Add annotation export to PDF
Fix slice index out-of-bounds on empty exam
Update SharePlay coordinator to handle new preset message
```

Avoid vague messages like `fix stuff`, `WIP`, or `changes`.

## What not to include in a PR

- Unrelated refactors or formatting changes mixed with functional changes
- Commented-out code left as a fallback
- Debug flags left set to `true`
- New files not referenced by anything in the project
- Real patient data of any kind — anonymized or synthetic test files only

## Running the tests

```bash
# visionOS app tests
xcodebuild test -project ATRIA.xcodeproj -scheme ATRIA \
  -destination 'platform=visionOS Simulator,name=Apple Vision Pro'

# macOS companion tests
xcodebuild test -project ATRIA.xcodeproj -scheme ATRIAmac \
  -destination 'platform=macOS'
```

Tests use Apple's **Swift Testing** framework (`@Suite`, `@Test` macros) — not XCTest. Only stores are unit-tested; views are not. See [Testing](README.md#testing) in the README for details on the test structure and mocks.

## License

By contributing to ATRIA, you agree that your contributions will be licensed under the [MIT License](LICENSE).
