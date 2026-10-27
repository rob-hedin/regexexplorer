# RegEx Explorer

A macOS app for building, testing and reusing named regular expressions.

Keep a library of regexes (such as "Email Address" or "IPv4 Address"), each with
its own test text, and see the results update as you type:

- **Match:** every match highlighted, with capture groups underlined in colour
  and listed in a table.
- **Replace:** a replacement template (`$0`, `$1`, `${name}`, `$$`) with a live,
  highlighted preview.
- **Filter:** only the lines that contain a match, or only those that don't.

Options for each regex cover ignoring case, `^` and `$` at line endings, `.`
matching newlines, ignoring whitespace, and simple word boundaries. A cheat sheet
window lists the syntax, and the **Swift Code** button writes Swift that does what
the editor shows, for the Swift 6 or Swift 5 language mode.

On first launch the library starts with a few common regexes to explore.

## Keyboard shortcuts

| Shortcut | Action |
| --- | --- |
| ⌘N | New regex |
| ⌘R | Rename the selected regex |
| Delete | Delete the selected regex (in the list) |
| ⌘L | Edit the pattern |
| ⌘1 / ⌘2 / ⌘3 | Match / Replace / Filter |
| ⇧⌘C | Show Swift code |
| ⌥⌘/ | Open the cheat sheet |

## Requirements

- macOS 27 or later
- Xcode 27 (Swift 6.4)

## Building

Open `RegexExplorer.xcodeproj` in Xcode and run the **RegexExplorer** scheme, or
from the command line:

```sh
xcodebuild -scheme RegexExplorer -destination 'platform=macOS' test
```

To sign, choose your team under Signing & Capabilities for the RegexExplorer
target. [Releasing](docs/releasing.md) covers archiving and notarizing.

## Layout

- `src/RegexExplorer/`: the app (SwiftUI, Swift Regex)
  - `App/`: the app entry point and menu commands
  - `Model/`: saved regexes, their options, the library, the starters and the cheat sheet
  - `Matching/`: compiling patterns, finding matches, replacing, filtering and writing Swift code
  - `Storage/`: reading and writing the JSON file
  - `Views/`: SwiftUI views
- `test/RegexExplorerTests/`: unit tests (Swift Testing)
- `docs/`: project notes, including the [plan](docs/plan.md)

Saved regexes live in `regexes.json` in the app's Application Support folder
(inside its sandbox container). Unit tests never touch that file.
