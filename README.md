# RegEx Explorer

A macOS app for building, testing and reusing named regular expressions.

Keep a library of regexes (such as "Email Address" or "IPv4 Address"), each with
its own test text, and see the results update as you type. The pattern is
coloured by syntax (groups, classes, quantifiers, escapes and anchors) as you type it.
Results show in one of three modes:

- **Match:** every match highlighted, with capture groups underlined in colour
  and listed in a table.
- **Replace:** a replacement template (`$0`, `$1`, `${name}`, `$$`) with a live,
  highlighted preview.
- **Filter:** only the lines that contain a match, or only those that don't.

Options for each regex cover ignoring case, `^` and `$` at line endings, `.`
matching newlines, ignoring whitespace, and simple word boundaries. A cheat sheet
window lists the syntax, and the **Code** button writes code that does what the
editor shows, in C#, C++, Go, Java, JavaScript / TypeScript, Kotlin, Perl,
PHP, Python, R, Ruby, Rust, Swift 5 or Swift 6.

On first launch the library starts with a few common regexes to explore.

## Keyboard shortcuts

| Shortcut | Action |
| --- | --- |
| ⌘N | New regex |
| ⌘R | Rename the selected regex |
| Delete | Delete the selected regex (in the list) |
| ⌘L | Edit the pattern |
| ⌘1 / ⌘2 / ⌘3 | Match / Replace / Filter |
| ⇧⌘C | Show code |
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

The project signs automatically with team SZMB83JQ7N. To build with a
different team, change it under Signing & Capabilities. [Releasing](docs/releasing.md)
covers archiving and notarizing.

## Layout

- `src/RegexExplorer/`: the app (SwiftUI, Swift Regex)
  - `App/`: the app entry point and menu commands
  - `Model/`: saved regexes, their options, the library, the starters and the cheat sheet
  - `Matching/`: compiling patterns, finding matches, replacing, filtering and writing code in each language
  - `Storage/`: reading and writing the JSON file
  - `Views/`: SwiftUI views
- `test/RegexExplorerTests/`: unit tests (Swift Testing)
- `docs/`: project notes, including the [plan](docs/plan.md)

Saved regexes live in `regexes.json` in the app's Application Support folder
(inside its sandbox container). Unit tests never touch that file.
