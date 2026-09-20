# Live Activity (Lock Screen + Dynamic Island timer)

The recording timer + distance can appear on the **Lock Screen** and in the
**Dynamic Island** while a Run/Walk/Hike records. All the code is in the repo:

- `ios/Shared/MovaraActivityAttributes.swift` — the ActivityKit attributes
- `ios/MovaraLiveActivity/` — the SwiftUI widget (lock screen + Dynamic Island)
- `ios/Runner/LiveActivityBridge.swift` — the method-channel bridge
- `lib/services/live_activity.dart` — start/update/end from the app
- `lib/screens/running_tab.dart` — drives it during recording
- `ios/Runner/Info.plist` — already has `NSSupportsLiveActivities`

It is **not compiled into the build by default** because the widget extension
needs its provisioning profile created **once in Xcode** — the command line
cannot mint the new App ID (`com.avneesh.movaraApp.MovaraLiveActivity`), even
with `-allowProvisioningUpdates` ("No Accounts" error).

## Enable it (one time, ~3 minutes)

1. Add the extension target to the Xcode project:

   ```bash
   cd frontend
   ruby ios/scripts/add_live_activity_target.rb ios/Runner.xcodeproj
   ```

2. Re-wire the bridge — in `ios/Runner/AppDelegate.swift`, replace the
   "LiveActivityBridge is wired up once…" comment with:

   ```swift
   if let registrar = engineBridge.pluginRegistry.registrar(forPlugin: "LiveActivityBridge") {
     LiveActivityBridge.register(with: registrar)
   }
   ```

3. Open the workspace and sign the extension:

   ```bash
   open ios/Runner.xcworkspace
   ```

   - Select the **Runner** project → TARGETS → **MovaraLiveActivity**
   - **Signing & Capabilities** → check **Automatically manage signing** →
     **Team** = your Apple ID (same as Runner, `5WYH7Z7786`)

4. Connect the iPhone, choose it as the destination, and press **▶ Run** once.
   Xcode creates the App ID + profile and installs. After this first Run,
   `./run-ios.sh` works with the extension too.

To turn it back off (so `./run-ios.sh` keeps working without the Xcode step),
restore `project.pbxproj` and the AppDelegate comment.
