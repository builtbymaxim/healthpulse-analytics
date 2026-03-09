//
//  RunningActivityWidgetBundle.swift
//  RunningActivityWidget
//
//  Widget bundle entry point for the running workout Live Activity.
//

import SwiftUI
import WidgetKit

// Stub widget required so SpringBoard can fetch at least one descriptor from
// this extension. Without it, a Live-Activity-only bundle causes a non-blocking
// "Failed to get descriptors" log on every app launch.
struct RunningActivityPlaceholderWidget: Widget {
    var body: some WidgetConfiguration {
        StaticConfiguration(kind: "RunningActivityPlaceholder", provider: PlaceholderProvider()) { _ in
            EmptyView()
        }
        .configurationDisplayName("Running")
        .description("Live Activity for active runs.")
        .supportedFamilies([])   // no families → never shown in gallery
    }
}

private struct PlaceholderProvider: TimelineProvider {
    func placeholder(in context: Context) -> PlaceholderEntry { PlaceholderEntry() }
    func getSnapshot(in context: Context, completion: @escaping (PlaceholderEntry) -> Void) { completion(PlaceholderEntry()) }
    func getTimeline(in context: Context, completion: @escaping (Timeline<PlaceholderEntry>) -> Void) { completion(Timeline(entries: [PlaceholderEntry()], policy: .never)) }
}

private struct PlaceholderEntry: TimelineEntry {
    let date = Date()
}

@main
struct RunningActivityWidgetBundle: WidgetBundle {
    var body: some Widget {
        RunningActivityLiveActivity()
        StrengthActivityLiveActivity()
        RunningActivityPlaceholderWidget()
    }
}
