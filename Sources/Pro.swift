import SwiftUI
import StoreKit

/// Clockout Pro: one non-consumable. Logging shifts is free forever; Pro is the back office.
///
/// Free: one job with its wage and tip-out rule, unlimited shifts, Tonight, the Shifts list,
/// real hourly, the monthly goal. Pro: Insights, the paycheck check, the tax year and its CSV,
/// and more than one job.
///
/// Anyone who first installed a build before Pro existed keeps everything. AppTransaction's
/// originalAppVersion is the build number they first installed. Only trusted in production:
/// sandbox and Xcode report made-up values, and App Review must see the real paywall.
@MainActor
@Observable
final class Pro {
    static let productID = "com.mattbusel.clockout.pro"
    /// The first build that has Pro in it. Anything earlier had every feature.
    static let firstFreemiumBuild = 2

    enum Reason: String, Identifiable { case insights, money, jobs, settings; var id: String { rawValue } }

    private(set) var unlocked: Bool
    private(set) var grandfathered = false
    private(set) var product: Product?
    var busy = false
    var message: String?
    var paywall: Reason? = nil

    private var updates: Task<Void, Never>?
    private let key = "clockout.pro.unlocked"
    private let forced: Bool

    /// `forced` is for screenshots and the review recording, which must not touch StoreKit.
    init(forced: Bool? = nil) {
        self.forced = forced != nil
        if let forced { unlocked = forced; return }
        unlocked = UserDefaults.standard.bool(forKey: key)
        updates = Task { [weak self] in
            for await result in Transaction.updates { await self?.apply(result) }
        }
        Task { await refresh() }
    }

    var price: String { product?.displayPrice ?? "$4.99" }

    func ask(_ why: Reason) { if !unlocked { paywall = why } }

    func refresh() async {
        guard !forced else { return }
        if product == nil { product = try? await Product.products(for: [Pro.productID]).first }
        for await result in Transaction.currentEntitlements { await apply(result) }
        if case .verified(let app)? = try? await AppTransaction.shared,
           app.environment == .production, (Int(app.originalAppVersion) ?? Int.max) < Pro.firstFreemiumBuild {
            grandfathered = true
            grant()
        }
    }

    func buy() async {
        guard !forced, !busy else { return }
        busy = true; message = nil
        defer { busy = false }
        if product == nil { product = try? await Product.products(for: [Pro.productID]).first }
        guard let product else {
            message = "The App Store did not answer. Check your connection and try again."
            return
        }
        do {
            switch try await product.purchase() {
            case .success(let result):
                await apply(result)
                if !unlocked { message = "Apple could not confirm the purchase. Try Restore in a minute." }
            case .pending:
                message = "Waiting for approval. Pro unlocks by itself once it is approved."
            case .userCancelled:
                break
            @unknown default:
                message = "Something unexpected happened. You were not charged."
            }
        } catch {
            message = "The purchase did not go through: \(error.localizedDescription)"
        }
    }

    func restore() async {
        guard !forced, !busy else { return }
        busy = true; message = nil
        defer { busy = false }
        do { try await AppStore.sync() } catch {
            if let e = error as? StoreKitError, case .userCancelled = e { return }
            message = "Could not reach the App Store. Check your connection and try again."
            return
        }
        await refresh()
        message = unlocked ? "Pro is unlocked. Welcome back." : "No Pro purchase found on this Apple ID."
    }

    private func apply(_ result: VerificationResult<StoreKit.Transaction>) async {
        guard case .verified(let t) = result, t.productID == Pro.productID else { return }
        if t.revocationDate == nil { grant() } else if !grandfathered { revoke() }
        await t.finish()
    }

    private func grant() {
        guard !unlocked else { return }
        withAnimation(.spring(response: 0.45, dampingFraction: 0.7)) { unlocked = true }
        paywall = nil
        UserDefaults.standard.set(true, forKey: key)
    }

    private func revoke() {
        unlocked = false
        UserDefaults.standard.set(false, forKey: key)
    }
}

// MARK: - Paywall: a night's receipt, with the amber sign lit

struct PaywallView: View {
    @Environment(Pro.self) private var pro
    @Environment(Store.self) private var store
    @Environment(\.dismiss) private var dismiss
    let reason: Pro.Reason
    @State private var lit = false

    var body: some View {
        ZStack {
            DinerBackground()
            ScrollView(showsIndicators: false) {
                VStack(alignment: .leading, spacing: 20) {
                    HStack {
                        Text("CLOCKOUT PRO").font(.money(13, .heavy)).tracking(3).foregroundStyle(Neon.amber)
                            .padding(.horizontal, 12).padding(.vertical, 7)
                            .overlay(Capsule().strokeBorder(Neon.amber.opacity(lit ? 0.9 : 0.2), lineWidth: 1.5))
                            .shadow(color: Neon.amber.opacity(lit ? 0.6 : 0), radius: 10)
                        Spacer()
                        Button { dismiss() } label: {
                            Image(systemName: "xmark").font(.system(size: 14, weight: .black)).foregroundStyle(Neon.grey)
                                .frame(width: 38, height: 38).background(Circle().fill(Neon.card))
                        }.buttonStyle(.plain).accessibilityLabel("Close")
                    }
                    VStack(alignment: .leading, spacing: 8) {
                        NeonText(text: headline, size: 30).fixedSize(horizontal: false, vertical: true)
                        Text("Logging shifts stays free forever. Pro does the back-office maths.")
                            .font(.ui(15, .medium)).foregroundStyle(Neon.grey)
                    }
                    receipt
                    priceBlock
                    if let m = pro.message {
                        Text(m).font(.ui(13, .semibold)).foregroundStyle(Neon.amber).frame(maxWidth: .infinity).multilineTextAlignment(.center)
                    }
                    AmberButton(title: pro.busy ? "One moment" : "Unlock Pro for \(pro.price)", icon: "lock.open.fill") {
                        Task { await pro.buy() }
                    }.disabled(pro.busy)
                    HStack {
                        GhostButton(title: "Restore purchase", icon: "arrow.clockwise") { Task { await pro.restore() } }
                        Spacer()
                        GhostButton(title: "Not now") { dismiss() }
                    }
                    Text("One payment, yours for good. No subscription. Family Sharing works. Every shift you have logged stays yours, Pro or not.")
                        .font(.ui(11.5, .medium)).foregroundStyle(Neon.dim).fixedSize(horizontal: false, vertical: true)
                }
                .padding(.horizontal, 20).padding(.top, 18).padding(.bottom, 40)
            }
        }
        .onAppear { withAnimation(.easeInOut(duration: 0.9).repeatCount(3, autoreverses: true)) { lit = true } }
        .onChange(of: pro.unlocked) { _, now in if now { dismiss() } }
    }

    var headline: String {
        switch reason {
        case .money: return "Is the check right?"
        case .jobs: return "Work more than one place?"
        default: return "Which nights pay?"
        }
    }

    /// What Pro adds, printed as the ticket at the end of a shift.
    var receipt: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text("ORDER #PRO").font(.money(12, .heavy)).foregroundStyle(Neon.ink)
                Spacer()
                Text(Date.now.formatted(.dateTime.month(.abbreviated).day())).font(.money(11)).foregroundStyle(Neon.ink2)
            }
            DottedLine()
            item("chart.bar.fill", "Insights", "Best weekday, best shift type, real hourly by job, 16 weeks of tips vs wages.")
            item("checkmark.seal.fill", "Paycheck check", "Pick the pay period, type the check, see if you were shorted.")
            item("doc.text.fill", "Tax year + CSV", "Cash tips, card tips and tip-out for the year, exported for your preparer.")
            item("person.2.fill", "More than one job", "Each with its own wage and tip-out rule.")
            DottedLine()
            HStack {
                Text("TOTAL").font(.money(13, .heavy)).foregroundStyle(Neon.ink)
                Spacer()
                Text(pro.price).font(.money(17, .heavy)).foregroundStyle(Neon.ink)
            }
            Text("THANK YOU, COME AGAIN").font(.money(10, .bold)).tracking(2).foregroundStyle(Neon.ink2).frame(maxWidth: .infinity)
        }
        .receipt()
    }

    func item(_ icon: String, _ title: String, _ body: String) -> some View {
        HStack(alignment: .top, spacing: 10) {
            Image(systemName: icon).font(.system(size: 13, weight: .black)).foregroundStyle(Neon.amber2).frame(width: 20)
            VStack(alignment: .leading, spacing: 2) {
                Text(title.uppercased()).font(.money(12, .heavy)).foregroundStyle(Neon.ink)
                Text(body).font(.ui(12, .medium)).foregroundStyle(Neon.ink2).fixedSize(horizontal: false, vertical: true)
            }
        }
    }

    var priceBlock: some View {
        HStack(alignment: .center) {
            VStack(alignment: .leading, spacing: 2) {
                NeonText(text: pro.price, size: 34)
                Text("ONCE. NOT A MONTH.").font(.ui(11, .heavy)).tracking(1.8).foregroundStyle(Neon.grey)
            }
            Spacer()
            Text("Less than\none shift's\ntip-out").font(.ui(12, .heavy)).multilineTextAlignment(.trailing).foregroundStyle(Neon.blue)
        }
        .tile()
    }
}

// MARK: - Locked pages

/// A Pro tab for a free user: the real page drawn from their own shifts, frosted, with a way in.
struct LockedPage<Content: View>: View {
    @Environment(Pro.self) private var pro
    let reason: Pro.Reason
    let title: String
    let pitch: String
    @ViewBuilder var content: Content

    var body: some View {
        ZStack {
            content.blur(radius: 10).allowsHitTesting(false).accessibilityHidden(true)
            LinearGradient(colors: [Neon.bg.opacity(0.2), Neon.bg.opacity(0.9)], startPoint: .top, endPoint: .bottom).ignoresSafeArea()
            VStack(spacing: 16) {
                ZStack {
                    Circle().strokeBorder(Neon.amber, lineWidth: 3).frame(width: 96, height: 96)
                        .shadow(color: Neon.amber.opacity(0.7), radius: 12).shadow(color: Neon.amber.opacity(0.3), radius: 30)
                    Image(systemName: "lock.fill").font(.system(size: 30, weight: .black)).foregroundStyle(Neon.amber)
                }
                NeonText(text: title, size: 26).multilineTextAlignment(.center)
                Text(pitch).font(.ui(15, .medium)).foregroundStyle(Neon.grey).multilineTextAlignment(.center).padding(.horizontal, 10)
                AmberButton(title: "See Clockout Pro", icon: "star.fill") { pro.ask(reason) }.padding(.horizontal, 30)
                Text("\(pro.price) once. Logging stays free.").font(.ui(12, .bold)).foregroundStyle(Neon.dim)
            }
            .padding(.horizontal, 24).padding(.bottom, 100)
        }
    }
}

/// Pro status in Jobs & settings, with Restore always in reach.
struct ProCard: View {
    @Environment(Pro.self) private var pro
    var body: some View {
        HStack(spacing: 14) {
            ZStack {
                Circle().fill(pro.unlocked ? Neon.amber : Neon.card2).frame(width: 40, height: 40)
                Image(systemName: pro.unlocked ? "checkmark" : "lock.fill").font(.system(size: 14, weight: .black)).foregroundStyle(pro.unlocked ? Neon.bg : Neon.grey)
            }
            VStack(alignment: .leading, spacing: 3) {
                Text(pro.unlocked ? "Clockout Pro" : "Clockout Pro, \(pro.price) once").font(.ui(16, .heavy)).foregroundStyle(Neon.white)
                Text(pro.unlocked ? (pro.grandfathered ? "Unlocked. Thanks for being here early." : "Unlocked. Thank you.") : "Insights, paycheck check, tax year, more jobs.")
                    .font(.ui(12, .medium)).foregroundStyle(Neon.grey)
                if let m = pro.message, pro.paywall == nil { Text(m).font(.ui(11.5, .semibold)).foregroundStyle(Neon.amber) }
            }
            Spacer(minLength: 6)
            if !pro.unlocked {
                VStack(alignment: .trailing, spacing: 8) {
                    Button { pro.ask(.settings) } label: {
                        Text("SEE").font(.ui(12, .black)).tracking(1.5).foregroundStyle(Neon.bg).padding(.horizontal, 14).padding(.vertical, 9)
                            .background(RoundedRectangle(cornerRadius: 10, style: .continuous).fill(Neon.amber))
                    }.buttonStyle(.plain)
                    Button { Task { await pro.restore() } } label: {
                        Text("Restore").font(.ui(11, .bold)).foregroundStyle(Neon.dim).underline()
                    }.buttonStyle(.plain)
                }
            }
        }
        .tile(padding: 14)
    }
}
