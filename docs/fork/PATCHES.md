# Fork patches

Source of truth for the fork's patches. Only the `dlux/fork-setup` branch edits this file.

- Upstream: [tiagomoraes/browbro](https://github.com/tiagomoraes/browbro).
- Mirror branches: `develop` (upstream's default branch) and `main`. Fast-forward only.
- `upstream-stable`: `v0.1.7`.
- Branch prefix: `dlux/`.
- Front page: `.github/README.md`. GitHub shows it on the default branch only. The default
  branch stays `develop` until the first release; then `release/latest` becomes the default
  branch and shows this page.
- Release name: `v<upstream version>-dlux.<N>`, for example `v0.1.7-dlux.1`. Release branch
  `release/<upstream version>-dlux.<N>`; `release/latest` points at the newest one.
- Check command for every patch (Xcode, no signing):
  `xcodegen generate && xcodebuild -scheme BrowBro build CODE_SIGNING_ALLOWED=NO`.

## Release order

1. `dlux/next-link-override`
2. `dlux/current-space-window`
3. `dlux/fork-setup`

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

- Base: `upstream-stable`
- Kind: upstream candidate
- What it does: keeps macOS from switching Spaces when BrowBro opens a link. Settings ›
  Behavior: "Open the link on a currently visible Space" (on by default, no permission)
  opens a new browser window, or raises a visible one with Accessibility. "Only on the
  current display" (off by default, asks for Accessibility) limits the search to the
  display of the frontmost window.
- Fork PR: [#5](https://github.com/dluxhu/browbro/pull/5)
- Upstream state: not offered
- Files: `CHANGELOG.md`, `Sources/AXWindows.swift`, `Sources/BrowserLauncher.swift`,
  `Sources/Preferences.swift`, `Sources/SettingsView.swift`, `Sources/SpaceWindows.swift`,
  `scripts/check-space-windows.sh`, `scripts/check-space-windows/main.swift`
- Check: `scripts/check-space-windows.sh`, then the check command above.

## dlux/fork-setup

- Base: `upstream-stable`
- Kind: fork-only (never offered upstream)
- What it does: the fork's front page and this patch list.
- Fork PR: [#4](https://github.com/dluxhu/browbro/pull/4)
- Upstream state: not offered (fork-only)
- Files: `.github/README.md`, `docs/fork/PATCHES.md`
- Check: none (docs only).

## Follow a new upstream stable release

1. Fast-forward `develop` and `main` to upstream.
2. Move `upstream-stable` to the newest stable tag.
   On `dlux/fork-setup`, change the `upstream-stable` version at the top of this file to that tag.
3. Merge that tag into each patch branch, in release order. Run the check command.
4. Push the branches.

## Cut a release

Only on the owner's word. Start `release/<version>-dlux.<N>` at the stable tag. Add one commit
per branch in release order: its net change against its merge base with the tag. Build, tag
`v<version>-dlux.<N>`, move `release/latest`. Nothing is pushed without the owner's go-ahead.
After the first release is pushed, set `release/latest` as the repo's default branch
(Settings › General). Later releases only move `release/latest`.
