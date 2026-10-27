# Releasing

RegEx Explorer is sandboxed and uses the hardened runtime, so it can ship on the
Mac App Store or as a notarized download.

## Before the first release

1. In Xcode, select the **RegexExplorer** target › Signing & Capabilities and
   choose your team. Signing is automatic.
2. Check the bundle identifier and the version (`MARKETING_VERSION`) and build
   number (`CURRENT_PROJECT_VERSION`) in the target's build settings.

## Notarized download (outside the App Store)

1. Product › Archive.
2. In the Organizer, choose **Distribute App** › **Direct Distribution**. Xcode
   signs the app with your Developer ID certificate, submits it for
   notarization, and staples the ticket when it's approved.
3. Export the app and share it, for example zipped or in a disk image.

From the command line, the same steps are:

```sh
xcodebuild -scheme RegexExplorer -configuration Release \
  -archivePath build/RegexExplorer.xcarchive archive
xcodebuild -exportArchive -archivePath build/RegexExplorer.xcarchive \
  -exportOptionsPlist ExportOptions.plist -exportPath build/export
ditto -c -k --keepParent build/export/RegexExplorer.app build/RegexExplorer.zip
xcrun notarytool submit build/RegexExplorer.zip --keychain-profile <profile> --wait
xcrun stapler staple build/export/RegexExplorer.app
```

`ExportOptions.plist` needs `method` set to `developer-id` and your `teamID`.
Create the keychain profile once with `xcrun notarytool store-credentials`.

## Mac App Store

1. Create the app record in App Store Connect with the same bundle identifier.
2. Product › Archive, then **Distribute App** › **App Store Connect**.
