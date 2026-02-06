//
//  RunningActivityWidgetBundle.swift
//  RunningActivityWidget
//
//  Widget bundle entry point for the running workout Live Activity.
//

import SwiftUI
import WidgetKit

@main
struct RunningActivityWidgetBundle: WidgetBundle {
    var body: some Widget {
        RunningActivityLiveActivity()
    }
}
