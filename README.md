# RegEx Explorer

A macOS app for building and testing reusable, named regular expressions.

Pick a saved regex from the list, edit its pattern and sample text, and see the
matches and capture groups highlighted live.

## Requirements

- macOS 27 or later
- Xcode with Swift 6.4

## Building

Open `RegexExplorer.xcodeproj` in Xcode and run the **RegexExplorer** scheme, or
from the command line:

```sh
xcodebuild -scheme RegexExplorer test
```

## Layout

- `src/RegexExplorer/`: the app (SwiftUI, Swift Regex)
  - `Model/`: saved regexes, their options, and the library that holds them
  - `Matching/`: compiling patterns and finding matches
  - `Storage/`: reading and writing the JSON file
  - `Views/`: SwiftUI views
- `test/RegexExplorerTests/`: unit tests (Swift Testing)
- `docs/`: project notes, including the [plan](docs/plan.md)

Saved regexes live in `regexes.json` in the app's Application Support folder.
