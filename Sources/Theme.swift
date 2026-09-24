import SwiftUI

/// Late-night diner. Navy, an amber neon tube, a cool blue, and receipt paper for the shifts.
enum Neon {
    static let bg = Color(red: 0.043, green: 0.059, blue: 0.102)          // #0B0F1A
    static let bg2 = Color(red: 0.067, green: 0.086, blue: 0.145)
    static let card = Color(red: 0.094, green: 0.118, blue: 0.188)
    static let card2 = Color(red: 0.125, green: 0.153, blue: 0.235)
    static let line = Color.white.opacity(0.08)
    static let line2 = Color.white.opacity(0.16)
    static let white = Color(red: 0.97, green: 0.96, blue: 0.93)
    static let grey = Color(red: 0.97, green: 0.96, blue: 0.93).opacity(0.62)
    static let dim = Color(red: 0.97, green: 0.96, blue: 0.93).opacity(0.34)
    static let amber = Color(red: 1.0, green: 0.69, blue: 0.13)            // #FFB020
    static let amber2 = Color(red: 0.86, green: 0.53, blue: 0.05)
    static let blue = Color(red: 0.35, green: 0.69, blue: 1.0)             // #5AB0FF
    static let blue2 = Color(red: 0.2, green: 0.42, blue: 0.7)
    static let green = Color(red: 0.42, green: 0.86, blue: 0.55)
    static let red = Color(red: 1.0, green: 0.45, blue: 0.42)
    static let paper = Color(red: 0.953, green: 0.922, blue: 0.847)       // #F3EBD8
    static let paper2 = Color(red: 0.89, green: 0.85, blue: 0.76)
    static let ink = Color(red: 0.12, green: 0.11, blue: 0.10)
    static let ink2 = Color(red: 0.12, green: 0.11, blue: 0.10).opacity(0.55)
    static let jobColors: [Color] = [amber, blue, green, Color(red: 0.95, green: 0.5, blue: 0.75), Color(red: 0.7, green: 0.6, blue: 1.0), red]
}

extension Font {
    static func big(_ size: CGFloat) -> Font { .system(size: size, weight: .heavy, design: .rounded) }
    static func ui(_ size: CGFloat, _ w: Font.Weight = .semibold) -> Font { .system(size: size, weight: w, design: .rounded) }
    static func money(_ size: CGFloat, _ w: Font.Weight = .bold) -> Font { .system(size: size, weight: w, design: .monospaced) }
}

struct Money {
    static func f(_ v: Double, _ c: String, cents: Bool = true) -> String {
        let neg = v < 0
        let n = NumberFormatter(); n.numberStyle = .decimal; n.minimumFractionDigits = cents ? 2 : 0; n.maximumFractionDigits = cents ? 2 : 0
        let s = n.string(from: NSNumber(value: abs(v))) ?? "0"
        return (neg ? "-" : "") + c + s
    }
    static func h(_ v: Double) -> String { v == v.rounded() ? String(format: "%.0f h", v) : String(format: "%.1f h", v) }
    static func pct(_ v: Double) -> String { String(format: "%.1f%%", v * 100) }
}

struct DinerBackground: View {
    var body: some View {
        ZStack {
            Neon.bg
            RadialGradient(colors: [Neon.amber.opacity(0.14), .clear], center: .init(x: 0.85, y: -0.05), startRadius: 10, endRadius: 420)
            RadialGradient(colors: [Neon.blue.opacity(0.10), .clear], center: .init(x: 0.0, y: 1.05), startRadius: 10, endRadius: 500)
        }.ignoresSafeArea()
    }
}

struct Eyebrow: View {
    let text: String
    init(_ t: String) { text = t }
    var body: some View { Text(text.uppercased()).font(.ui(11, .heavy)).tracking(2).foregroundStyle(Neon.dim) }
}

/// Amber neon tube text: the glow is two soft shadows.
struct NeonText: View {
    let text: String
    var size: CGFloat = 34
    var color: Color = Neon.amber
    var body: some View {
        Text(text).font(.money(size, .heavy)).foregroundStyle(color)
            .shadow(color: color.opacity(0.55), radius: 8).shadow(color: color.opacity(0.25), radius: 22)
    }
}

extension View {
    func tile(padding: CGFloat = 16, radius: CGFloat = 20) -> some View {
        self.padding(padding)
            .background(RoundedRectangle(cornerRadius: radius, style: .continuous).fill(Neon.card))
            .overlay(RoundedRectangle(cornerRadius: radius, style: .continuous).strokeBorder(Neon.line))
    }
    /// Receipt paper: cream card with a zig-zag torn bottom edge.
    func receipt() -> some View {
        self.padding(.horizontal, 14).padding(.top, 12).padding(.bottom, 16)
            .background(ReceiptShape().fill(Neon.paper).shadow(color: .black.opacity(0.35), radius: 8, y: 4))
    }
}

struct ReceiptShape: Shape {
    func path(in r: CGRect) -> Path {
        var p = Path()
        let tooth: CGFloat = 7
        p.move(to: CGPoint(x: r.minX, y: r.minY))
        p.addLine(to: CGPoint(x: r.maxX, y: r.minY))
        p.addLine(to: CGPoint(x: r.maxX, y: r.maxY - tooth))
        var x = r.maxX
        var up = false
        while x > r.minX {
            let nx = max(r.minX, x - tooth)
            p.addLine(to: CGPoint(x: nx, y: up ? r.maxY - tooth : r.maxY))
            up.toggle(); x = nx
        }
        p.closeSubpath()
        return p
    }
}

struct AmberButton: View {
    let title: String
    var icon: String? = nil
    var action: () -> Void
    var body: some View {
        Button(action: action) {
            HStack(spacing: 8) {
                if let icon { Image(systemName: icon).font(.system(size: 15, weight: .black)) }
                Text(title).font(.ui(15, .heavy))
            }
            .foregroundStyle(Neon.bg).frame(maxWidth: .infinity).padding(.vertical, 15)
            .background(RoundedRectangle(cornerRadius: 14, style: .continuous).fill(Neon.amber).shadow(color: Neon.amber.opacity(0.4), radius: 16, y: 6))
        }.buttonStyle(.plain)
    }
}

struct GhostButton: View {
    let title: String
    var icon: String? = nil
    var action: () -> Void
    var body: some View {
        Button(action: action) {
            HStack(spacing: 6) {
                if let icon { Image(systemName: icon).font(.system(size: 13, weight: .bold)) }
                Text(title).font(.ui(13, .heavy))
            }
            .foregroundStyle(Neon.grey).padding(.horizontal, 14).padding(.vertical, 10)
            .background(RoundedRectangle(cornerRadius: 11, style: .continuous).fill(Neon.card2)).overlay(RoundedRectangle(cornerRadius: 11, style: .continuous).strokeBorder(Neon.line2))
        }.buttonStyle(.plain)
    }
}

/// A chip row for shift types, jobs, months.
struct Chip: View {
    let text: String
    let on: Bool
    var color: Color = Neon.amber
    var action: () -> Void
    var body: some View {
        Button(action: action) {
            Text(text).font(.ui(13, .heavy)).foregroundStyle(on ? Neon.bg : Neon.grey)
                .padding(.horizontal, 13).padding(.vertical, 8)
                .background(Capsule().fill(on ? color : Neon.card2)).overlay(Capsule().strokeBorder(on ? color : Neon.line2))
        }.buttonStyle(.plain)
    }
}

/// Money field: label above, big monospaced entry, decimal pad.
struct MoneyField: View {
    let label: String
    @Binding var text: String
    var prefix: String = "$"
    var hint: String = "0"
    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Eyebrow(label)
            HStack(spacing: 4) {
                Text(prefix).font(.money(18)).foregroundStyle(Neon.dim)
                TextField(hint, text: $text).font(.money(24, .heavy)).foregroundStyle(Neon.white).keyboardType(.decimalPad)
            }
        }
        .padding(.horizontal, 14).padding(.vertical, 10)
        .background(RoundedRectangle(cornerRadius: 14, style: .continuous).fill(Neon.bg2)).overlay(RoundedRectangle(cornerRadius: 14, style: .continuous).strokeBorder(Neon.line2))
    }
}

struct Stat: View {
    let value: String
    let label: String
    var color: Color = Neon.white
    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(value).font(.money(22, .heavy)).foregroundStyle(color).lineLimit(1).minimumScaleFactor(0.6)
            Text(label).font(.ui(11, .heavy)).foregroundStyle(Neon.dim)
        }.frame(maxWidth: .infinity, alignment: .leading).tile(padding: 14, radius: 16)
    }
}
