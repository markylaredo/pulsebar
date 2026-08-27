import AppKit
import Foundation
import Observation

@MainActor
@Observable
final class SystemInformationViewModel {
    private(set) var system: SystemInformationSnapshot?
    private(set) var displays: [DisplaySnapshot] = []
    private(set) var interfaces: [NetworkInterfaceSnapshot] = []
    private(set) var isLoading = true

    private let systemReader = SystemInformationReader()
    private let networkProvider = NetworkInspectorProvider()

    func run() async {
        if system == nil {
            async let systemSnapshot = systemReader.read()
            async let networkInterfaces = networkProvider.interfaces()
            displays = DisplayInformationReader().read()
            system = await systemSnapshot
            interfaces = await networkInterfaces
            isLoading = false
        }

        while !Task.isCancelled {
            do { try await Task.sleep(for: .seconds(15)) } catch { return }
            let updatedInterfaces = await networkProvider.interfaces()
            guard !Task.isCancelled else { return }
            if interfaces != updatedInterfaces { interfaces = updatedInterfaces }
        }
    }

    func refreshDisplays() {
        let updatedDisplays = DisplayInformationReader().read()
        if displays != updatedDisplays { displays = updatedDisplays }
    }
}
