# Changelog

All notable changes to this project will be documented in this file.

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



