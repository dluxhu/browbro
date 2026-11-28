# Fork patches

Source of truth for the fork's patches. Only the `dlux/fork-setup` branch edits this file.

- Upstream: [tiagomoraes/browbro](https://github.com/tiagomoraes/browbro).
- Mirror branches: `develop` (upstream's default branch) and `main`. Fast-forward only.
- `upstream-stable`: `v0.1.7`.
- Branch prefix: `dlux/`.
- Release name: `v<upstream version>-dlux.<N>`, for example `v0.1.7-dlux.1`. Release branch
  `release/<upstream version>-dlux.<N>`; `release/latest` points at the newest one.
- Check command for every patch (Xcode, no signing):
  `xcodegen generate && xcodebuild -scheme BrowBro build CODE_SIGNING_ALLOWED=NO`.

## Release order

1. `dlux/next-link-override`
2. `dlux/fork-setup`

`dlux/current-space-window` joins the list after it moves to `upstream-stable`.

## dlux/next-link-override

- Base: `upstream-stable`
- Kind: upstream candidate
- What it does: adds a "Next link only" picker to the menu-bar dropdown. The chosen browser
  or Chrome profile opens the next link, ahead of modifier mode and the picker. Then the
  choice clears. It is held in memory only.
- Fork PR: [#3](https://github.com/dluxhu/browbro/pull/3)
- Upstream state: not offered
- Files: `CHANGELOG.md`, `Sources/MenuDropdownView.swift`, `Sources/PickerPanel.swift`,
  `Sources/TargetCatalog.swift`
- Check: the check command above.

## dlux/current-space-window

- Status: being redesigned; moves to v0.1.7 later. Until then it is
  `feat/current-space-window`, based on upstream `develop`.
- Kind: upstream candidate
- What it does: opens the link in a browser window in the current Space.
- Fork PR: [#2](https://github.com/dluxhu/browbro/pull/2)
- Upstream state: not offered
- Not in the release order yet.

## dlux/fork-setup

- Base: `upstream-stable`
- Kind: fork-only (never offered upstream)
- What it does: the fork's front page and this patch list.
- Fork PR: see the README.
- Upstream state: not offered (fork-only)
- Files: `.github/README.md`, `docs/fork/PATCHES.md`
- Check: none (docs only).

## Follow a new upstream stable release

1. Fast-forward `develop` and `main` to upstream.
2. Move `upstream-stable` to the newest stable tag.
3. Merge that tag into each patch branch, in release order. Run the check command.
4. Push the branches.

## Cut a release

Only on the owner's word. Start `release/<version>-dlux.<N>` at the stable tag. Add one commit
per branch in release order: its net change against its merge base with the tag. Build, tag
`v<version>-dlux.<N>`, move `release/latest`. Nothing is pushed without the owner's go-ahead.
