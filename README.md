# Comments Plugin

<img src="/Logo.png" style="width: 64px;" />

CommentsPlugin is a plugin specifically designed for Xcode. It meticulously replicates the convenient comment functionality of Sublime Text, providing an elegant and efficient code commenting experience.

## Build
```shell
cd CommentsPlugin
xcodebuild -resolvePackageDependencies -scmProvider system
```

## Tests

The extension and the Swift package compile the same `CommentToggle.swift` core.
Tests require Swift 6 or later and use Swift Testing, with no external packages.
They can run with Command Line Tools alone; building the app and checking its
XcodeKit integration still require a full Xcode installation.

```shell
swift test --disable-xctest --enable-code-coverage
swift test -c release --disable-xctest
```

The suite includes 42 regression tests and two opt-in performance tests. It covers
single/multiple selections, mixed indentation and comments, blank lines, all
Foundation whitespace types, LF/CR/CRLF and Unicode separators, missing final
newlines, emoji and combining marks, cursor clamping, EOF/out-of-bounds positions,
invalid buffer entries, completion callbacks, large buffers, and long lines.
Negative positions and reversed line ranges are safe no-ops; extreme columns do
not overflow.

`Tests/CommentsPluginCoreTests/LegacySourceEditorCommand.swift` freezes the
algorithm from commit `8a5dbce`, replacing only XcodeKit types and logging.
Explicit expectations, exhaustive single-line column boundaries, and 10,000
deterministic generated cases (three toggles each) compare both text and every
selection endpoint with that reference. Existing quirks are intentionally kept:
unevenly indented comments may only partially uncomment; end-column-zero and
all-blank selections keep their original cursor adjustments; Unicode columns
still use the original mixture of UTF-16 offsets and Swift Character counts.

The optimized core caches line analysis, scans prefixes instead of repeatedly
trimming full lines, removes the comment marker without regular expressions,
and calculates selection-related Character counts only where needed. Command
debug logging is removed. Cached metadata uses memory proportional to the
number of selected lines.

Large single selections covering all buffer lines (at least 256 lines) calculate
their edits in a temporary array and commit once through `completeBuffer`.
Small, partial, and multiple selections retain incremental line updates. The
whole-file path restores both selection endpoints after committing, since the
editor can adjust selections when text changes. Apple documents that
[`lines` and `completeBuffer` synchronize](https://developer.apple.com/documentation/xcodekit/xcsourcetextbuffer/lines)
and that [text mutations update selections](https://developer.apple.com/documentation/xcodekit/xcsourcetextbuffer/selections).
This matters for editor performance: an ordinary `NSMutableArray` benchmark
does not include XcodeKit's change tracking or Xcode's processing of each edit.

Whole-file regression tests verify one complete-buffer commit, no writes to the
original line array, unchanged text/selection semantics, selection restoration
after an editor reset, and 200 generated documents toggled three times each.

Run the performance comparison separately to avoid competing test workloads:

```shell
COMMENTS_PLUGIN_BENCHMARK=1 swift test -c release --disable-xctest --filter CommentTogglePerformanceTests
```

Each workload validates text and selections, warms both implementations, then
reports the median of seven runs in alternating order. Buffer setup is excluded
from timing, and logging is disabled in the reference as well. Timing has no
pass/fail threshold, so machine load does not make ordinary tests flaky.

To validate and benchmark a real source file without adding it to this repository:

```shell
COMMENTS_PLUGIN_BENCHMARK_FILE=/absolute/path/to/Source.swift swift test -c release --disable-xctest --filter ExternalSourcePerformanceTests
```

The supplied `ScriptInterpreterResources.swift` sample has 7,925 physical lines
and 306,863 bytes. Both toggles match the reference text and selection positions;
the batch path replaces 7,146 live line mutations with one complete-buffer
assignment. Local Release computation is approximately 11 ms for commenting and
8 ms for uncommenting. The separate staged measurement includes copying, joining,
and a simulated editor reset; neither measurement includes real Xcode IPC,
change tracking, syntax highlighting, or UI latency. A full Xcode installation
is required to confirm the end-to-end improvement.

Example Release results on an Apple M3 virtual machine, macOS 15.6.1,
Swift 6.1.2 (milliseconds; actual results vary by machine):

| Workload | Reference | Optimized | Speedup |
| --- | ---: | ---: | ---: |
| Comment 50,000 lines | 117.33 | 34.71 | 3.38× |
| Uncomment 50,000 lines | 194.42 | 39.23 | 4.96× |
| Mixed Unicode / blank, 50,000 lines | 361.07 | 122.82 | 2.94× |
| Blank, 50,000 lines | 74.00 | 27.77 | 2.66× |
| Long lines, approximately 10 MB | 6.77 | 1.92 | 3.52× |

## Installation

1. Run the application at least once, then close it.
2. Go to System Preferences > Extensions > Xcode Source Editor and enable this extension.
3. Reopen Xcode and you can find this extension from Xcode Menu > Editor.

## Setting Hot Key

1. After installation, open Xcode > Preferences > Key Bindings.
2. Search for "CommentsPlugin".
3. Assign it a new hot key, here "command + /" is recommended.

# License

Copyright 2023-2024 CHUNQIAN SHEN  

Licensed under the Apache License, Version 2.0 (the "License"); you may not use this file except in compliance with the License.

You may obtain a copy of the License at

[http://www.apache.org/licenses/LICENSE-2.0](http://www.apache.org/licenses/LICENSE-2.0)

Unless required by applicable law or agreed to in writing, software distributed under the License is distributed on an "AS IS" BASIS, WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.  See the License for the specific language governing permissions and limitations under the License.
