# mac-ff-cfg-diff

Safari-ish Firefox on macOS. [Lepton](https://github.com/black7375/Firefox-UI-Fix) (Proton style) + a small diff.

## Install

```bash
curl -fsSL https://raw.githubusercontent.com/youp211/mac-ff-cfg-diff/main/apply.sh | bash
```

Restart Firefox.

- check only (from a clone): `./apply.sh --check`
- undo: copy `chrome/` and `user.js` back from `safari-cfg-backup-*` in the profile folder

## Mods

- tabs + toolbar on one row
- window buttons, toolbar buttons, address bar, tabs all on one line
- tab strip hidden with a single tab
- small tabs, active tab in the accent colour
- centred address bar
- Flexible Space works again (Customize Toolbar)
- compact or normal density both line up (compact is closest to Safari)

## Files

- `userChrome.safari.css` - CSS diff
- `user-overrides.js` - pref diff
- `apply.sh` - installs Lepton (pinned) + both diffs

Tested: Firefox 160, macOS 27.
