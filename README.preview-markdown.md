# @b-agentic/preview-markdown

A standalone Pi package for inline Markdown previews with Tokyo Night Moon/Day
cards, global theme switching, active-branch preview history, and exact source
copying.

## Install

After the package is published, install it with Pi:

```bash
pi install npm:@b-agentic/preview-markdown
```

The package registers the `preview_markdown` tool and these commands:

- `/preview-markdown:render <prompt>` requests a one-response preview.
- `/preview-markdown:theme` selects the globally persisted Moon or Day theme.
- `/preview-markdown:list` lists the 20 most recent successful active-branch
  previews for exact Markdown source copying.
- `Ctrl+Shift+M` copies the latest preview source.

## Raw GitHub alternative

The npm package and the raw installer use the same canonical extension source:
`pi/extensions/b-agentic-preview-markdown.ts`.

For a version-pinned GitHub install without the npm package, use the standalone
raw installer after the corresponding public release tag exists:

```bash
curl -fsSL https://raw.githubusercontent.com/dhoaibao/b-agentic/v0.1.0/pi/scripts/install-preview-markdown.sh | bash -s -- v0.1.0
```

The raw installer preserves unrelated Pi files and installs no other b-agentic
extension or dependency. Run `/reload` in Pi after either installation route.

## Scope

This package contains only the Markdown preview extension and package-facing
documentation. Pi itself and its core extension packages are peer dependencies;
they are not bundled in this package.
