# Storage format

RegEx Explorer keeps every saved regex in one JSON file, `regexes.json`, in the app's
Application Support folder. Because the app is sandboxed, that is:

```
~/Library/Containers/com.robhedin.RegexExplorer/Data/Library/Application Support/RegexExplorer/regexes.json
```

The format is described by a JSON schema ([JSON Schema draft 2020-12](https://json-schema.org/draft/2020-12/schema)):

| Schema | Published at | Copy in this repo |
| --- | --- | --- |
| Current | https://robhedin.com/schemas/regexexplorer-v20261028.json | [`schemas/regexexplorer-v20261028.json`](../schemas/regexexplorer-v20261028.json) |

Each file names its schema in a `$schema` field, so editors that understand JSON
schemas (VS Code, for example) can check and complete it.

## Example

```json
{
  "$schema" : "https://robhedin.com/schemas/regexexplorer-v20261028.json",
  "regexes" : [
    {
      "createdAt" : "2026-10-28T15:29:48Z",
      "id" : "0F3C1B6E-1D2A-4C5B-9E8F-7A6B5C4D3E2F",
      "invertsFilter" : false,
      "mode" : "match",
      "modifiedAt" : "2026-10-28T15:29:48Z",
      "name" : "US Zip Code",
      "options" : {
        "allowsExtendedSyntax" : false,
        "anchorsMatchLineEndings" : true,
        "dotMatchesNewlines" : false,
        "ignoresCase" : false,
        "usesSimpleWordBoundaries" : false
      },
      "pattern" : "^\\d{5}(-\\d{4})?$",
      "replacement" : "",
      "sampleText" : "12345\n12345-6789\n1234"
    }
  ],
  "version" : 1
}
```

The app writes keys in alphabetical order, indented, with dates in ISO 8601 (UTC,
whole seconds).

## The file

| Field | Type | Required | Meaning |
| --- | --- | --- | --- |
| `$schema` | string (URL) | No | The schema the file follows. Files written before the schema existed don't have it. |
| `version` | integer | Yes | The format version, currently `1`. Later releases use it to migrate older files. |
| `regexes` | array of [regexes](#each-regex) | Yes | The saved regexes, in the order the sidebar lists them. |

## Each regex

| Field | Type | Default | Meaning |
| --- | --- | --- | --- |
| `id` | string (UUID) | Required | Identifies the regex. |
| `name` | string | Required | The name shown in the sidebar, such as "Email Address". |
| `pattern` | string | `""` | The regular expression, in Swift Regex syntax. |
| `sampleText` | string | `""` | The text the pattern is tried against. |
| `options` | [options](#options) | All off | How the pattern is compiled. |
| `mode` | `"match"`, `"replace"` or `"filter"` | `"match"` | Which result the editor shows. |
| `replacement` | string | `""` | The Replace template: `$0` is the whole match, `$1` or `${1}` a group, `${name}` a named group, and `$$` a dollar sign. |
| `invertsFilter` | boolean | `false` | In Filter mode, keep the lines without a match instead of those with one. |
| `createdAt` | string (date-time) | When loaded | When the regex was created. |
| `modifiedAt` | string (date-time) | `createdAt` | When the regex was last changed. |

## Options

Each option is a boolean, and a missing option is off.

| Field | In the editor | Meaning |
| --- | --- | --- |
| `ignoresCase` | Ignore case | Letters match regardless of case. |
| `anchorsMatchLineEndings` | ^ $ match each line | `^` and `$` match at the start and end of every line, not just the whole text. |
| `dotMatchesNewlines` | . matches newlines | `.` also matches newline characters. |
| `allowsExtendedSyntax` | Ignore whitespace | Whitespace in the pattern is ignored and `#` starts a comment. |
| `usesSimpleWordBoundaries` | Simple word boundaries | `\b` uses simple word-character transitions instead of Unicode word rules. |

## How the app reads the file

- Only `id` and `name` are required. Any other missing field gets its default, so
  older files keep loading as fields are added.
- An unknown `mode` is read as `match` rather than failing the whole file.
- If the file can't be read at all, the app moves it aside as
  `regexes.unreadable-<timestamp>.json` and starts a new one, so nothing is overwritten.
- If there is no file, the app creates one with a few starter regexes.

The schema is stricter than the app: it rejects unknown fields and modes, so it
catches typos in a hand-edited file.

## Changing the format

When the storage format changes:

1. Copy the current schema to a new file named for the day of the change,
   `schemas/regexexplorer-vYYYYMMDD.json`, and change its `$id` to match. Keep the old
   schema files, since files in the wild still point at them.
2. Update the new schema, and set `RegexLibraryStore.File.schemaURL` to its URL.
3. If older files can no longer be read as they are, raise `File.currentVersion`,
   change the schema's `version` constant, and teach `RegexLibraryStore` to migrate the
   older version when it loads.
4. Update this document: the schema table, the example and the field tables.
5. Publish the new schema at `https://robhedin.com/schemas/` under the same file name.
