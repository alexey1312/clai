# Changelog

All notable changes to this project will be documented in this file.

## [1.2.0] - 2026-02-03

### Other

- Parallelize model discovery in ModelsManager 

* perf(core): parallelize model discovery in ModelsManager

- Optimize `clai models` and `clai models list` by running MLX and Ollama model discovery concurrently using `async let`.
- This reduces the latency of these commands by overlapping file system I/O (MLX) with network checks (Ollama).
- Fixed precedence issue with await and method chaining.

Co-authored-by: alexey1312 <36570774+alexey1312@users.noreply.github.com>

* perf(core): parallelize model discovery in ModelsManager

- Optimize `clai models` and `clai models list` by running MLX and Ollama model discovery concurrently using `async let`.
- This reduces the latency of these commands by overlapping file system I/O (MLX) with network checks (Ollama).
- Fixed precedence issue and linter `hoistAwait` violation.

Co-authored-by: alexey1312 <36570774+alexey1312@users.noreply.github.com>

* perf(core): parallelize model discovery in ModelsManager

- Optimize `clai models` and `clai models list` by running MLX and Ollama model discovery concurrently using `async let`.
- This reduces the latency of these commands by overlapping file system I/O (MLX) with network checks (Ollama).
- Fixed linter errors `hoistAwait` and `docComments` encountered in CI.

Co-authored-by: alexey1312 <36570774+alexey1312@users.noreply.github.com>

* chore: update tools

* fix(ci): disable docComments and wrapPropertyBodies rules

These rules appear to have different defaults between local and CI
SwiftFormat installations, causing formatting check failures.

Co-Authored-By: Claude Opus 4.5 <noreply@anthropic.com>

---------

Co-authored-by: google-labs-jules[bot] <161369871+google-labs-jules[bot]@users.noreply.github.com>
Co-authored-by: Claude Opus 4.5 <noreply@anthropic.com> by @alexey1312 in [#57](https://github.com/alexey1312/clai/pull/57)

- Cache Ollama availability check to optimize discovery performance 

* perf(providers): cache Ollama availability check

- Implements caching for `OllamaChecker.isAvailable` with a 5-second TTL.
- Reduces redundant network requests to `localhost:11434` during provider discovery.
- Significantly improves performance for interactive sessions (e.g., `clai chat`) and scenarios where Ollama is unavailable (avoiding connection timeouts).
- Uses `NSLock` and `nonisolated(unsafe)` to ensure thread safety and Swift 6 concurrency compliance.

Co-authored-by: alexey1312 <36570774+alexey1312@users.noreply.github.com>

* style(providers): fix modifier order in OllamaChecker

- Reorders `nonisolated(unsafe) private static` to `private static nonisolated(unsafe)` to satisfy SwiftFormat linting rules.
- Fixes CI failure `(modifierOrder) Use consistent ordering for member modifiers`.

Co-authored-by: alexey1312 <36570774+alexey1312@users.noreply.github.com>

* style(providers): fix modifier order (private nonisolated(unsafe) static)

- Reordered modifiers in `OllamaChecker.swift` to `private nonisolated(unsafe) static` to comply with SwiftFormat rules enforced in CI.
- Fixes `(modifierOrder) Use consistent ordering for member modifiers` lint error.

Co-authored-by: alexey1312 <36570774+alexey1312@users.noreply.github.com>

* refactor: use actor-based caching for availability check

Replace NSLock-based cache with an actor to improve concurrency safety
and simplify code.

* style(history): fix wrapPropertyBodies lint errors

- Expanded single-line property bodies in `HistoryTypes.swift` and `HistoryIndexer.swift` to multiple lines.
- Satisfies strict SwiftFormat configuration in CI (`wrapPropertyBodies`).

Co-authored-by: alexey1312 <36570774+alexey1312@users.noreply.github.com>

---------

Co-authored-by: google-labs-jules[bot] <161369871+google-labs-jules[bot]@users.noreply.github.com> by @alexey1312 in [#64](https://github.com/alexey1312/clai/pull/64)

- Fix config provider selection and improve error handling 

* feat: enhance provider config and caching logic

Load and utilize additional configuration settings for provider management,
enabling a customizable fallback chain. Ensure that ProviderManager
considers user-defined provider preferences and defaults when constructing the
chain. Improve caching mechanisms for OllamaChecker using concurrency-safe
access with NSLock, optimizing network request handling. These updates
enhance configurability and efficiency, aligning better with user
requirements and system performance goals.

* fix(config): improve error handling for config loading

Refactor Config.load() to throw typed errors instead of silently
returning defaults. Create default config file automatically if
missing. Add ConfigError enum with user-friendly error messages
including YAML syntax error location with code snippets.

Update ClaiEngine init to propagate config errors and make all
command entry points use try with ClaiEngine initialization.

* fix: after review by @alexey1312 in [#66](https://github.com/alexey1312/clai/pull/66)


### Performance

- **core**: Parallelize prompt generation and provider discovery  by @google-labs-jules[bot] in [#48](https://github.com/alexey1312/clai/pull/48)

- **providers**: Parallelize availability checks with lazy instantiation  by @google-labs-jules[bot] in [#51](https://github.com/alexey1312/clai/pull/51)

- **cache**: Delay expiration cleanup on startup  by @alexey1312 in [#53](https://github.com/alexey1312/clai/pull/53)

- **context**: Optimize tldr check in ContextGatherer  by @alexey1312 in [#55](https://github.com/alexey1312/clai/pull/55)

- **core**: Parallelize MLX model discovery  by @alexey1312 in [#59](https://github.com/alexey1312/clai/pull/59)

- **core**: Concurrent help command context gathering  by @alexey1312 in [#61](https://github.com/alexey1312/clai/pull/61)

- **providers**: Lazily initialize platform and MLX checks  by @alexey1312 in [#63](https://github.com/alexey1312/clai/pull/63)

- **cache**: Optimize Ollama provider availability check  by @alexey1312 in [#65](https://github.com/alexey1312/clai/pull/65)


### Refactor

- **ui**: Update Noora integration with interactive prompts  by @alexey1312 in [#49](https://github.com/alexey1312/clai/pull/49)

- **ui**: Extract MarkdownRenderer from TerminalUI by @alexey1312

- Remove Linux-specific conditions and improve table rendering by @alexey1312


### Styling

- **ui**: Improve nested list rendering and coloring  by @google-labs-jules[bot] in [#47](https://github.com/alexey1312/clai/pull/47)

- **ui**: Add markdown table support by @google-labs-jules[bot]

- **ui**: Improve spinner feedback with success/failure states  by @alexey1312 in [#54](https://github.com/alexey1312/clai/pull/54)


## [1.1.2] - 2026-01-24

### Miscellaneous Tasks

- Add .xcsift.toml by @alexey1312


### Other

- Replace unsafe locks with actor-based caching for tldr availability 

* fix(concurrency): replace NSLock with actor for async-safe tldr caching

NSLock cannot be used in async contexts in Swift 6. Replace with
actor-based caching for thread-safe tldr availability checks.
Also add @discardableResult to withConnection to silence warning.

* fix(concurrency): remove async let to fix data race errors in Swift 6

Replace async let with sequential execution in ClaiEngine and
ModelsManager to avoid data race errors with closures and self
in Swift 6 strict concurrency mode.

* chore: update Package.resolved

---------

Co-authored-by: Claude <noreply@anthropic.com> by @alexey1312 in [#46](https://github.com/alexey1312/clai/pull/46)


### Performance

- **lazy-init**: Defer context gathering until after cache miss  by @google-labs-jules[bot] in [#32](https://github.com/alexey1312/clai/pull/32)

- **cache**: Optimize ResponseCache initialization to be lazy  by @google-labs-jules[bot] in [#34](https://github.com/alexey1312/clai/pull/34)

- **core**: Cache tldr availability in ContextGatherer  by @google-labs-jules[bot] in [#36](https://github.com/alexey1312/clai/pull/36)

- **providers**: Avoid unnecessary Ollama network checks  by @google-labs-jules[bot] in [#40](https://github.com/alexey1312/clai/pull/40)

- **concurrency**: Parallelize model discovery in ModelsManager  by @google-labs-jules[bot] in [#42](https://github.com/alexey1312/clai/pull/42)

- **startup**: Parallelize provider discovery and context gathering  by @google-labs-jules[bot] in [#45](https://github.com/alexey1312/clai/pull/45)


### Styling

- **ui**: Improve markdown code block rendering  by @google-labs-jules[bot] in [#31](https://github.com/alexey1312/clai/pull/31)

- **ui**: Improve markdown rendering for lists and rules  by @google-labs-jules[bot] in [#33](https://github.com/alexey1312/clai/pull/33)

- **ui**: Make progress bars and horizontal rules responsive to terminal width  by @google-labs-jules[bot] in [#35](https://github.com/alexey1312/clai/pull/35)

- **ui**: Improve markdown code block rendering  by @google-labs-jules[bot] in [#39](https://github.com/alexey1312/clai/pull/39)

- **ui**: Implement GitHub-flavored markdown callouts  by @google-labs-jules[bot] in [#41](https://github.com/alexey1312/clai/pull/41)

- **ui**: Add markdown link support  by @google-labs-jules[bot] in [#44](https://github.com/alexey1312/clai/pull/44)


## [1.1.1] - 2026-01-18

### Bug Fixes

- **ci**: Enable static stdlib for Linux tests by @alexey1312


### Features

- **providers**: Implement FoundationModel provider and add attribution by @alexey1312

- **providers**: Add Linux-compatible Ollama pull method by @alexey1312


### Other

- **deps**: Bump swift-argument-parser, Noora, and Yams by @alexey1312


## [1.1.0] - 2026-01-18

### Documentation

- **openspec**: Add proposals for future clai features by @alexey1312


### Features

- **chat**: Add interactive chat session with history by @alexey1312

- **history**: Add semantic search and pattern analysis  by @alexey1312 in [#29](https://github.com/alexey1312/clai/pull/29)

- Add shell integration  by @alexey1312 in [#30](https://github.com/alexey1312/clai/pull/30)


### Miscellaneous Tasks

- Merge branch 'main' of github.com:alexey1312/clai by @alexey1312


## [1.0.6] - 2026-01-18

### Features

- **ui**: Add blockquote styling to terminal output  by @google-labs-jules[bot] in [#5](https://github.com/alexey1312/clai/pull/5)

- **ux**: Make suggest command interactive when arguments missing  by @google-labs-jules[bot] in [#9](https://github.com/alexey1312/clai/pull/9)

- Enable SQLite WAL mode and optimize synchronous settings in ResponseCache  by @google-labs-jules[bot] in [#11](https://github.com/alexey1312/clai/pull/11)

- **ui**: Enable inline styles in headers  by @google-labs-jules[bot] in [#10](https://github.com/alexey1312/clai/pull/10)

- **docs**: Add docs and man-page generation commands by @alexey1312


### Miscellaneous Tasks

- **ui**: Enhance interactive prompts with color  by @google-labs-jules[bot] in [#12](https://github.com/alexey1312/clai/pull/12)

- **mise**: Update xcsift by @alexey1312


### Other

- Fix nested ANSI style rendering in CLI output  by @google-labs-jules[bot] in [#4](https://github.com/alexey1312/clai/pull/4)

- ⚡ Bolt: Add index on ResponseCache.createdAt  by @google-labs-jules[bot] in [#7](https://github.com/alexey1312/clai/pull/7)

- 🎨 Palette: Add italic support and fix nested styling  by @google-labs-jules[bot] in [#6](https://github.com/alexey1312/clai/pull/6)

- **deps**: Update mise and dev tool versions by @alexey1312

- **hooks**: Migrate to static .githooks directory by @alexey1312


### Performance

- Optimize cache cleanup to improve startup time  by @google-labs-jules[bot] in [#8](https://github.com/alexey1312/clai/pull/8)

- **cache**: Optimize sha256Hash hex encoding  by @google-labs-jules[bot] in [#26](https://github.com/alexey1312/clai/pull/26)

- **providers**: Parallelize provider availability checks  by @google-labs-jules[bot] in [#28](https://github.com/alexey1312/clai/pull/28)


### Styling

- **ui**: Harmonize ANSI color palette using Theme enum  by @google-labs-jules[bot] in [#25](https://github.com/alexey1312/clai/pull/25)

- **ui**: Add animated spinner for long-running operations  by @google-labs-jules[bot] in [#27](https://github.com/alexey1312/clai/pull/27)


## [1.0.5] - 2025-12-28

### Features

- Add interactive prompt and conventional commits by @alexey1312


### Miscellaneous Tasks

- Replace pre-commit with hk for git hooks by @alexey1312


### Other

- Merge branch 'main' of github.com:alexey1312/clai by @alexey1312

- ⚡ Bolt: Use non-blocking process execution in ContextGatherer  by @google-labs-jules[bot] in [#2](https://github.com/alexey1312/clai/pull/2)

- 🎨 Palette: Enhance CLI Markdown rendering with bold and composite styles  by @google-labs-jules[bot] in [#3](https://github.com/alexey1312/clai/pull/3)


## [1.0.4] - 2025-12-26

### Documentation

- Consolidate AI agent instructions into CLAUDE.md by @alexey1312


## [1.0.3] - 2025-12-13

### Features

- Support Library/Caches location for MLX models by @alexey1312


### Miscellaneous Tasks

- Add automatic Homebrew tap update on release by @alexey1312


## [1.0.2] - 2025-12-13

### Features

- Add MLX metallib bundling for Homebrew distribution by @alexey1312


## [1.0.1] - 2025-12-13

### Bug Fixes

- Conditionally enable MLX trait for Apple Silicon only by @alexey1312

- Conditionally enable MLX trait for Apple Silicon only by @alexey1312


### Miscellaneous Tasks

- Add xcsift formatting to build and test output by @alexey1312


### Other

- Merge branch 'main' of github.com:alexey1312/clai by @alexey1312

- Fix Linux build and tests, verify release workflow 

* fix: Linux build compatibility for Swift 6.1

- Make Noora conditional (macOS only) to avoid Observation linker bug on Linux
- Add FoundationNetworking import for URLSession on Linux
- Use FileHandle.synchronize() for stdout flushing on Linux (concurrency-safe)
- Add SPM cache for Linux in CI and release workflows
- Update Package.swift with conditional platform dependencies

* style: Fix indentation in ClaiEngine.swift

* style: Fix indentation in conditional imports

* style: Fix indentation in conditional imports

* Add --static-swift-stdlib

* Add --static-swift-stdlib

---------

Co-authored-by: Claude <noreply@anthropic.com> by @alexey1312 in [#1](https://github.com/alexey1312/clai/pull/1)


## [1.0.0] - 2025-12-13

### Other

- Initial commit by @alexey1312



