import ActivityKit
import SwiftUI
import WidgetKit

/// The Lock Screen banner and Dynamic Island for a recording activity: the
/// activity emoji, a self-ticking elapsed timer, and distance in km.
@available(iOS 16.1, *)
struct MovaraLiveActivityWidget: Widget {
  var body: some WidgetConfiguration {
    ActivityConfiguration(for: MovaraActivityAttributes.self) { context in
      // Lock Screen / banner presentation.
      VStack(alignment: .leading, spacing: 8) {
        // Brand row so it's clearly the Movara app.
        HStack(spacing: 6) {
          Text("MOVARA")
            .font(.system(size: 12, weight: .heavy, design: .rounded))
            .tracking(2)
            .foregroundColor(.orange)
          Text("· \(context.attributes.activityLabel.uppercased())")
            .font(.system(size: 11, weight: .semibold))
            .foregroundColor(.secondary)
          Spacer()
        }
        HStack(spacing: 14) {
          Text(context.attributes.emoji)
            .font(.system(size: 34))
          Text(timerInterval: timerRange(context), countsDown: false)
            .font(.system(size: 30, weight: .bold, design: .rounded))
            .monospacedDigit()
          Spacer()
          VStack(alignment: .trailing, spacing: 2) {
            Text(String(format: "%.2f", context.state.distanceKm))
              .font(.system(size: 22, weight: .bold, design: .rounded))
              .monospacedDigit()
            Text("km")
              .font(.caption2)
              .foregroundColor(.secondary)
          }
        }
      }
      .padding()
      .activityBackgroundTint(Color.black.opacity(0.55))
      .activitySystemActionForegroundColor(Color.orange)
    } dynamicIsland: { context in
      DynamicIsland {
        DynamicIslandExpandedRegion(.leading) {
          Text(context.attributes.emoji).font(.title2)
        }
        DynamicIslandExpandedRegion(.trailing) {
          VStack(alignment: .trailing) {
            Text(String(format: "%.2f km", context.state.distanceKm))
              .font(.headline)
              .monospacedDigit()
          }
        }
        DynamicIslandExpandedRegion(.center) {
          Text(timerInterval: timerRange(context), countsDown: false)
            .font(.system(.title2, design: .rounded))
            .monospacedDigit()
            .multilineTextAlignment(.center)
        }
      } compactLeading: {
        Text(context.attributes.emoji)
      } compactTrailing: {
        Text(timerInterval: timerRange(context), countsDown: false)
          .monospacedDigit()
          .frame(maxWidth: 46)
      } minimal: {
        Text(context.attributes.emoji)
      }
      .keylineTint(Color.orange)
    }
  }

  /// A timer range from when recording started to far in the future, so the
  /// system renders a live, self-updating stopwatch without frequent pushes.
  private func timerRange(
    _ context: ActivityViewContext<MovaraActivityAttributes>
  ) -> ClosedRange<Date> {
    let start = context.attributes.startedAt
    return start...start.addingTimeInterval(60 * 60 * 24)
  }
}
