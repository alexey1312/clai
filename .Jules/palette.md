# Palette's Journal

## 2024-05-22 - Inline Styles in CLI Output
**Learning:** Hardcoded styling logic often ignores composition (e.g., bullet points + code + bold). Users expect Markdown-like rendering to work everywhere, even in CLI.
**Action:** When implementing custom Markdown parsers for CLI, always implement a `applyInlineStyles` function that composes styles instead of exclusive if/else blocks for line types.

## 2024-05-23 - Fixing Nested ANSI Styles
**Learning:** Using `\u{001B}[0m` (Reset All) in style helpers breaks nested styling (e.g. bold text containing colored code). Using specific resets (`[22m` for bold, `[39m` for color) allows styles to compose correctly.
**Action:** Always use specific ANSI reset codes corresponding to the attribute being set, rather than the global reset.

## 2025-05-27 - CLI Interactive Prompts
**Learning:** Defaulting to "exit" or "first option" on any invalid input (including typos) frustrates users. Interactive CLIs must provide feedback and a chance to retry.
**Action:** Always implement a `while true` loop for interactive selections, catching invalid input and displaying a helpful error message before prompting again. Handle EOF (Ctrl-D) explicitly to allow exit.
