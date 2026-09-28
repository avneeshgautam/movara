import Flutter
import Foundation

#if canImport(ActivityKit)
import ActivityKit
#endif

/// Bridges Flutter to ActivityKit so the recording screen can show a live
/// timer on the Lock Screen and in the Dynamic Island. No-ops before iOS 16.1
/// or when Live Activities are disabled.
enum LiveActivityBridge {
  static func register(with registrar: FlutterPluginRegistrar) {
    let channel = FlutterMethodChannel(
      name: "movara/live_activity",
      binaryMessenger: registrar.messenger())
    channel.setMethodCallHandler { call, result in
      let args = call.arguments as? [String: Any]
      switch call.method {
      case "start":
        if #available(iOS 16.1, *) { start(args) }
        result(true)
      case "update":
        if #available(iOS 16.1, *) { update(args) }
        result(true)
      case "end":
        if #available(iOS 16.1, *) { end() }
        result(true)
      default:
        result(FlutterMethodNotImplemented)
      }
    }
  }

  #if canImport(ActivityKit)
  @available(iOS 16.1, *)
  private static func start(_ args: [String: Any]?) {
    guard ActivityAuthorizationInfo().areActivitiesEnabled else { return }
    // Never stack two -- but end only the activities that exist *now*. The
    // old code called end() here, whose Task ran after the request below and
    // ended every activity, including the one just started, so the card
    // vanished immediately.
    let previous = Activity<MovaraActivityAttributes>.activities
    if !previous.isEmpty {
      Task {
        for activity in previous {
          await activity.end(dismissalPolicy: .immediate)
        }
      }
    }
    let label = args?["label"] as? String ?? "Activity"
    let emoji = args?["emoji"] as? String ?? "🏃"
    // Backdated so a resumed timer shows its full elapsed time.
    let elapsed = (args?["elapsedSeconds"] as? NSNumber)?.doubleValue ?? 0
    let showsDistance = args?["showsDistance"] as? Bool ?? true
    let attributes = MovaraActivityAttributes(
      activityLabel: label, emoji: emoji,
      startedAt: Date().addingTimeInterval(-elapsed),
      showsDistance: showsDistance)
    let state = MovaraActivityAttributes.ContentState(distanceKm: 0)
    do {
      _ = try Activity.request(
        attributes: attributes, contentState: state, pushType: nil)
    } catch {
      // Starting a Live Activity can fail (limits, disabled) — ignore.
    }
  }

  @available(iOS 16.1, *)
  private static func update(_ args: [String: Any]?) {
    let km = (args?["distanceKm"] as? NSNumber)?.doubleValue ?? 0
    let state = MovaraActivityAttributes.ContentState(distanceKm: km)
    Task {
      for activity in Activity<MovaraActivityAttributes>.activities {
        await activity.update(using: state)
      }
    }
  }

  @available(iOS 16.1, *)
  private static func end() {
    Task {
      for activity in Activity<MovaraActivityAttributes>.activities {
        await activity.end(dismissalPolicy: .immediate)
      }
    }
  }
  #else
  @available(iOS 16.1, *)
  private static func start(_ args: [String: Any]?) {}
  @available(iOS 16.1, *)
  private static func update(_ args: [String: Any]?) {}
  @available(iOS 16.1, *)
  private static func end() {}
  #endif
}
