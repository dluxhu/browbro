# BrowBro (dluxhu fork)

This is a fork of [tiagomoraes/browbro](https://github.com/tiagomoraes/browbro). It adds a
small set of patches on top of the newest upstream stable release. Upstream's own
[README](../README.md) describes the app.

## Patches

| Patch | What it does | Fork PR |
|---|---|---|
| Next link only | A "Next link only" picker in the menu-bar dropdown. The next link opens in the chosen browser or Chrome profile; then routing returns to normal | [#3](https://github.com/dluxhu/browbro/pull/3) |
| Current Space window | Opens the link in a browser window in the current Space. Being redesigned | [#2](https://github.com/dluxhu/browbro/pull/2) |
| Fork docs | This front page and the patch list (fork-only) | [#4](https://github.com/dluxhu/browbro/pull/4) |

The patch list, with the branch and base of each patch, is in
[docs/fork/PATCHES.md](../docs/fork/PATCHES.md).

## Branches

- `develop` and `main` mirror upstream. Fast-forward only.
- `upstream-stable` is the newest upstream stable release tag. All patch branches start there.
- `dlux/<name>` is one patch. Each has a fork PR against `upstream-stable`.
