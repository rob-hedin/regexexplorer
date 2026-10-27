# Releasing

RegEx Explorer is sandboxed and uses the hardened runtime, so it can ship on the
Mac App Store or as a notarized download.

## Before the first release

1. The project signs automatically with team `SZMB83JQ7N`. Your Mac needs a
   Developer ID Application certificate for that team (Xcode › Settings ›
   Accounts › Manage Certificates) to export a notarized download.
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

## Disk image for easy installing

After exporting the notarized app, build a disk image that opens with the app
beside a link to Applications, so installing is a drag:

```sh
scripts/make-dmg.sh build/export/RegexExplorer.app <profile>
```

The script copies the app into `build/RegexExplorer.dmg`, signs the disk image with
your Developer ID Application certificate, notarizes it and staples the ticket, so
Gatekeeper accepts it even offline. Set `SIGNING_IDENTITY` if you have more than one
Developer ID certificate. Share the `.dmg` instead of the zip.

## Mac App Store

1. Create the app record in App Store Connect with the same bundle identifier.
2. Product › Archive, then **Distribute App** › **App Store Connect**.
