import SwiftUI
import Observation

@main
struct ClockoutApp: App {
    @State private var store: Store
    @State private var router = Router()
    @State private var pro: Pro
    init() {
        let a = ProcessInfo.processInfo.arguments
        let demo = a.contains("-shot") || a.contains("-demoAutoplay")
        _store = State(initialValue: Store(demo: demo))
        // Screenshots and the review recording show Pro; the paywall shots show it locked.
        let shot = a.firstIndex(of: "-shot").flatMap { $0 + 1 < a.count ? a[$0 + 1] : nil }
        let lockedShot = shot.map { $0.hasPrefix("paywall") || $0.hasPrefix("locked") } ?? false
        _pro = State(initialValue: demo ? Pro(forced: !lockedShot) : Pro())
    }
    var body: some Scene {
        WindowGroup {
            RootView().environment(store).environment(router).environment(pro).preferredColorScheme(.dark).tint(Neon.amber)
                .onAppear { router.applyShotArgs(store, pro); Autopilot.shared.run(store, router) }
        }
    }
}

enum Tab: String, CaseIterable {
    case home = "Tonight", shifts = "Shifts", insights = "Insights", money = "Money"
    var icon: String {
        switch self {
        case .home: return "moon.stars.fill"
        case .shifts: return "receipt.fill"
        case .insights: return "chart.bar.fill"
        case .money: return "banknote.fill"
        }
    }
}

/// The add form's state lives here so the review autopilot and -shot can fill it.
@Observable
final class Draft {
    var editingId: UUID? = nil
    var jobIndex = 0
    var kind = "Dinner"
    var date = Date.now
    var useHours = false
    var start = Date.now
    var end = Date.now
    var hours = ""
    var sales = ""
    var cash = ""
    var card = ""
    var tipout = ""
    var tipoutTouched = false
    var note = ""
    static let kinds = ["Lunch", "Dinner", "Double", "Close", "Brunch", "Other"]

    static func time(_ minutes: Int) -> Date {
        let c = Calendar.current
        return c.date(bySettingHour: (minutes / 60) % 24, minute: minutes % 60, second: 0, of: .now) ?? .now
    }
    static func minutes(_ d: Date) -> Int { let c = Calendar.current.dateComponents([.hour, .minute], from: d); return (c.hour ?? 0) * 60 + (c.minute ?? 0) }

    func reset(_ store: Store) {
        editingId = nil; jobIndex = 0; kind = "Dinner"; date = .now; useHours = false
        start = Draft.time(16 * 60); end = Draft.time(22 * 60 + 30)
        hours = ""; sales = ""; cash = ""; card = ""; tipout = ""; tipoutTouched = false; note = ""
    }
    func load(_ s: Shift, _ store: Store) {
        editingId = s.id
        jobIndex = store.jobs.firstIndex { $0.id == s.jobId } ?? 0
        kind = s.kind; date = Day.date(s.date); useHours = s.useHours
        start = Draft.time(s.start); end = Draft.time(s.end)
        hours = s.useHours ? Draft.num(s.hours) : ""
        sales = Draft.num(s.sales); cash = Draft.num(s.cash); card = Draft.num(s.card); tipout = Draft.num(s.tipout); tipoutTouched = true; note = s.note
    }
    static func num(_ v: Double) -> String { v == 0 ? "" : v == v.rounded() ? String(format: "%.0f", v) : String(format: "%.2f", v) }
    static func val(_ s: String) -> Double { Double(s.replacingOccurrences(of: ",", with: ".").trimmingCharacters(in: .whitespaces)) ?? 0 }

    var workedHours: Double {
        if useHours { return max(0, Draft.val(hours)) }
        var m = Draft.minutes(end) - Draft.minutes(start)
        if m <= 0 { m += 1440 }
        return Double(m) / 60
    }
    func job(_ store: Store) -> Job? { store.jobs.indices.contains(jobIndex) ? store.jobs[jobIndex] : nil }
    func autoTipout(_ store: Store) -> Double { store.autoTipout(job: job(store), sales: Draft.val(sales), tips: Draft.val(cash) + Draft.val(card)) }
    func effectiveTipout(_ store: Store) -> Double { tipoutTouched ? Draft.val(tipout) : autoTipout(store) }
    func take(_ store: Store) -> Double { (job(store)?.wage ?? 0) * workedHours + Draft.val(cash) + Draft.val(card) - effectiveTipout(store) }
    func rate(_ store: Store) -> Double { workedHours > 0 ? take(store) / workedHours : 0 }

    func build(_ store: Store) -> Shift? {
        guard let j = job(store) else { return nil }
        var s = Shift(date: Day.key(date), jobId: j.id, kind: kind)
        if let id = editingId { s.id = id }
        s.useHours = useHours; s.start = Draft.minutes(start); s.end = Draft.minutes(end); s.hours = Draft.val(hours)
        s.sales = Draft.val(sales); s.cash = Draft.val(cash); s.card = Draft.val(card)
        s.tipout = (effectiveTipout(store) * 100).rounded() / 100
        s.note = note.trimmingCharacters(in: .whitespaces)
        return s
    }
}

@Observable
final class Router {
    var tab: Tab = .home
    var adding = false
    var moneyPage = 0            // 0 paycheck, 1 tax
    var settings = false
    var draft = Draft()
    var shiftFilterJob: UUID? = nil
    var shiftMonth: String? = nil
    var shot = ""

    func applyShotArgs(_ s: Store, _ pro: Pro) {
        let a = ProcessInfo.processInfo.arguments
        guard let i = a.firstIndex(of: "-shot"), i + 1 < a.count else { return }
        shot = a[i + 1]
        switch shot {
        case "add":
            draft.reset(s)
            draft.kind = "Dinner"; draft.sales = "1112"; draft.cash = "61"; draft.card = "144.40"
            adding = true
        case "shifts": tab = .shifts
        case "insights": tab = .insights
        case "paycheck": tab = .money; moneyPage = 0
        case "tax": tab = .money; moneyPage = 1
        case "paywall": tab = .insights; pro.ask(.insights)
        case "locked": tab = .money
        default: break
        }
    }
}

struct RootView: View {
    @Environment(Store.self) private var store
    @Environment(Router.self) private var router
    @Environment(Pro.self) private var pro
    var body: some View {
        @Bindable var router = router
        @Bindable var pro = pro
        ZStack(alignment: .bottom) {
            DinerBackground()
            Group {
                switch router.tab {
                case .home: HomeView()
                case .shifts: ShiftsView()
                case .insights:
                    if pro.unlocked { InsightsView() } else {
                        LockedPage(reason: .insights, title: "Which nights pay?", pitch: "Your best weekday, your best shift type, real hourly by job and sixteen weeks of tips against wages, drawn from the shifts you log.") { InsightsView() }
                    }
                case .money:
                    if pro.unlocked { MoneyView() } else {
                        LockedPage(reason: .money, title: "Is the check right?", pitch: "Check a paycheck against your logged hours, see the whole tax year, and export it as a CSV for whoever does your taxes.") { MoneyView() }
                    }
                }
            }
            PunchTabBar(selection: $router.tab) { router.draft.reset(store); router.adding = true }.padding(.bottom, 2)
        }
        .fullScreenCover(isPresented: $router.adding) { AddShiftView() }
        .sheet(isPresented: $router.settings) {
            SettingsView().presentationBackground(Neon.bg2).presentationDetents([.large])
                .sheet(item: $pro.paywall) { r in PaywallView(reason: r).presentationBackground(Neon.bg) }
        }
        .sheet(item: Binding(get: { router.settings ? nil : pro.paywall }, set: { pro.paywall = $0 })) { r in PaywallView(reason: r).presentationBackground(Neon.bg) }
    }
}

struct Page<Content: View>: View {
    @ViewBuilder var content: Content
    var body: some View {
        ScrollView(showsIndicators: false) {
            VStack(alignment: .leading, spacing: 16) { content }.padding(.horizontal, 16).padding(.top, 8).padding(.bottom, 120)
        }
    }
}

/// Custom tab bar with a big amber punch button in the middle.
struct PunchTabBar: View {
    @Binding var selection: Tab
    var punch: () -> Void
    var body: some View {
        HStack(spacing: 0) {
            tabButton(.home); tabButton(.shifts)
            Button(action: punch) {
                ZStack {
                    Circle().fill(Neon.amber).frame(width: 60, height: 60).shadow(color: Neon.amber.opacity(0.55), radius: 18, y: 6)
                    Image(systemName: "plus").font(.system(size: 26, weight: .black)).foregroundStyle(Neon.bg)
                }.offset(y: -14)
            }.buttonStyle(.plain).frame(maxWidth: .infinity)
            tabButton(.insights); tabButton(.money)
        }
        .padding(.horizontal, 6).padding(.top, 10).padding(.bottom, 8)
        .background(RoundedRectangle(cornerRadius: 26, style: .continuous).fill(Neon.bg2.opacity(0.96)).overlay(RoundedRectangle(cornerRadius: 26, style: .continuous).strokeBorder(Neon.line2)).shadow(color: .black.opacity(0.5), radius: 20, y: 8))
        .padding(.horizontal, 14)
    }
    func tabButton(_ t: Tab) -> some View {
        Button { withAnimation(.snappy(duration: 0.25)) { selection = t } } label: {
            VStack(spacing: 4) {
                Image(systemName: t.icon).font(.system(size: 18, weight: .bold))
                Text(t.rawValue).font(.ui(10, .heavy))
            }
            .foregroundStyle(selection == t ? Neon.amber : Neon.dim).frame(maxWidth: .infinity).padding(.vertical, 4)
        }.buttonStyle(.plain)
    }
}
