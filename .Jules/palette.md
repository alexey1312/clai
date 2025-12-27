# Palette's Journal

## 2024-05-22 - Inline Styles in CLI Output
**Learning:** Hardcoded styling logic often ignores composition (e.g., bullet points + code + bold). Users expect Markdown-like rendering to work everywhere, even in CLI.
**Action:** When implementing custom Markdown parsers for CLI, always implement a `applyInlineStyles` function that composes styles instead of exclusive if/else blocks for line types.
