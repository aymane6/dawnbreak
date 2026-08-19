import SwiftUI
import WidgetKit

/// The widget extension's entry point.
///
/// One widget, and it is not a home-screen widget: AlarmKit draws the ringing alarm as a Live
/// Activity, and the Live Activity's views have to live in an extension. Without this target
/// the alarm rings with the system's default presentation and the mission button never
/// appears on the lock screen.
@main
struct DawnbreakWidgetBundle: WidgetBundle {
    var body: some Widget {
        AlarmLiveActivity()
        NextAlarmWidget()
    }
}
