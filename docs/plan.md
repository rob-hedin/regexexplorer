# Plan

1. **Foundation:** Sandboxed SwiftUI app (Swift 6.4, macOS 27+), the saved-regex
   model (name, pattern, sample text, options), JSON storage in Application
   Support, and unit tests for matching and storage.
2. **Screen design review:** Agree the screen design before building the UI.
3. **Split view:** Named list on the left (add, rename, delete). Detail on the
   right: regex field, sample text, and read-only highlighted matches with
   capture groups that update live. An invalid pattern shows an inline error.
4. **Options and cheat sheet:** Toggles for ignore case, `^`/`$` at line
   endings, dot matches newlines, extended syntax, and simple word boundaries.
   A toolbar button opens the cheat sheet in its own window.
5. **Replace, Filter and Swift code** (added): a Match / Replace / Filter
   switch, a Swift Code sheet for Swift 6 or Swift 5, and starter regexes on
   first launch.
6. **Ready to publish:** App icon, keyboard shortcuts, signing and notarization
   settings, README.
