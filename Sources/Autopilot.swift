import SwiftUI
import Observation

/// Drives the real screens for the App Review recording (-demoAutoplay).
@Observable
final class Autopilot {
    static let shared = Autopilot()
    static var on: Bool { ProcessInfo.processInfo.arguments.contains("-demoAutoplay") }
    private var running = false
    @MainActor private func wait(_ s: Double) async { try? await Task.sleep(for: .seconds(s)) }
    @MainActor
    func run(_ store: Store, _ router: Router) {
        guard Autopilot.on, !running else { return }
        running = true
        Task { @MainActor in
            await wait(3)
            let d = router.draft
            d.reset(store)
            router.adding = true; await wait(2)
            d.kind = "Close"; await wait(1)
            d.end = Draft.time(60); await wait(1)
            for v in ["9", "98", "984"] { d.sales = v; await wait(0.35) }
            await wait(0.6)
            for v in ["5", "52"] { d.cash = v; await wait(0.35) }
            await wait(0.6)
            for v in ["1", "13", "131", "131.", "131.5"] { d.card = v; await wait(0.3) }
            await wait(1.6)
            if let s = d.build(store) { store.shifts.append(s); store.save() }
            router.adding = false; await wait(2.5)
            router.tab = .shifts; await wait(3.5)
            router.tab = .insights; await wait(3.5)
            router.tab = .money; router.moneyPage = 0; await wait(3.5)
            router.moneyPage = 1; await wait(3.5)
            router.tab = .home; await wait(2)
            try? Data("ok".utf8).write(to: URL.documentsDirectory.appending(path: "demo_done"))
        }
    }
}
