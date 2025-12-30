## 2024-12-30 - Swift Environment Crash
**Learning:** The `mise`-installed Swift 6.2.3 compiler consistently crashes with a segmentation fault (Signal 11) on Linux when running `swift test`.
**Action:** Rely on static analysis and `swiftlint` for verification in this environment until the toolchain is fixed. Do not assume `swift test` will work.
