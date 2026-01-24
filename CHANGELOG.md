# Changelog

All notable changes to this project will be documented in this file.

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



