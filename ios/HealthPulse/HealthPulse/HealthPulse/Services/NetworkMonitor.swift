//
//  NetworkMonitor.swift
//  HealthPulse
//
//  Observes network reachability using NWPathMonitor.
//

import Foundation
import Network
import Combine

@MainActor
class NetworkMonitor: ObservableObject {
    static let shared = NetworkMonitor()

    @Published private(set) var isConnected = true
    @Published private(set) var connectionType: NWInterface.InterfaceType?

    private let monitor = NWPathMonitor()
    private let queue = DispatchQueue(label: "com.healthpulse.NetworkMonitor", qos: .utility)

    private init() {
        monitor.pathUpdateHandler = { [weak self] path in
            let connected = path.status == .satisfied
            let type: NWInterface.InterfaceType? = {
                if path.usesInterfaceType(.wifi) { return .wifi }
                if path.usesInterfaceType(.cellular) { return .cellular }
                return nil
            }()
            Task { @MainActor [weak self] in
                self?.isConnected = connected
                self?.connectionType = type
            }
        }
        monitor.start(queue: queue)
    }

    /// Thread-safe synchronous read — safe to call from any isolation context.
    /// NWPathMonitor.currentPath is documented as thread-safe.
    nonisolated var isCurrentlyConnected: Bool {
        monitor.currentPath.status == .satisfied
    }
}
