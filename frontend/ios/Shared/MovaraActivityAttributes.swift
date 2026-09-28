import Foundation

#if canImport(ActivityKit)
import ActivityKit

/// Shared between the app (which starts/updates the activity) and the widget
/// extension (which draws it). Live Activities require iOS 16.1+.
@available(iOS 16.1, *)
struct MovaraActivityAttributes: ActivityAttributes {
  public struct ContentState: Codable, Hashable {
    /// Distance covered so far, in kilometres.
    var distanceKm: Double
  }

  /// "Run" / "Walk" / "Hike".
  var activityLabel: String
  /// The activity emoji, e.g. 🏃.
  var emoji: String
  /// When recording began — the widget derives a self-ticking timer from this.
  var startedAt: Date
  /// False for gym workouts, which have a timer but no distance.
  var showsDistance: Bool
}
#endif
