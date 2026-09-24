import Foundation
import Observation

enum TipoutKind: String, Codable, CaseIterable { case none, sales, tips }

struct Job: Codable, Identifiable, Hashable {
    var id = UUID()
    var name: String
    var wage: Double = 2.13
    var tipoutKind: TipoutKind = .sales
    var tipoutPct: Double = 3
    var color: Int = 0
}

struct Shift: Codable, Identifiable, Hashable {
    var id = UUID()
    var date: String                      // yyyy-MM-dd, the day the shift started
    var jobId: UUID
    var kind: String = "Dinner"
    var useHours: Bool = false
    var start: Int = 16 * 60              // minutes from midnight
    var end: Int = 23 * 60
    var hours: Double = 6
    var sales: Double = 0
    var cash: Double = 0
    var card: Double = 0
    var tipout: Double = 0
    var note: String = ""

    var workedHours: Double {
        if useHours { return max(0, hours) }
        var m = end - start
        if m <= 0 { m += 1440 }
        return Double(m) / 60
    }
    var tips: Double { cash + card }
}

enum Day {
    static let cal: Calendar = { var c = Calendar(identifier: .iso8601); c.timeZone = .current; return c }()
    static let f: DateFormatter = { let f = DateFormatter(); f.dateFormat = "yyyy-MM-dd"; f.calendar = cal; f.timeZone = .current; return f }()
    static func key(_ d: Date) -> String { f.string(from: d) }
    static func date(_ k: String) -> Date { f.date(from: k) ?? .now }
    static var today: String { key(.now) }
    static func add(_ k: String, _ n: Int) -> String { key(cal.date(byAdding: .day, value: n, to: date(k))!) }
    /// Monday = 0 … Sunday = 6
    static func dow(_ k: String) -> Int { (cal.component(.weekday, from: date(k)) + 5) % 7 }
    static func weekStart(_ k: String) -> String { add(k, -dow(k)) }
    static func month(_ k: String) -> String { String(k.prefix(7)) }
    static func year(_ k: String) -> String { String(k.prefix(4)) }
    static let names = ["Mon", "Tue", "Wed", "Thu", "Fri", "Sat", "Sun"]
    static func short(_ k: String) -> String { date(k).formatted(.dateTime.weekday(.abbreviated).month(.abbreviated).day()) }
    static func clock(_ minutes: Int) -> String {
        let h = (minutes / 60) % 24, m = minutes % 60
        let ap = h < 12 ? "am" : "pm"
        let hh = h % 12 == 0 ? 12 : h % 12
        return m == 0 ? "\(hh)\(ap)" : String(format: "%d:%02d%@", hh, m, ap)
    }
}

@Observable
final class Store {
    var jobs: [Job] = []
    var shifts: [Shift] = []
    var goal: Double = 3200
    var currency: String = "$"
    var checkIncludesCard: Bool = true
    private var saveTask: Task<Void, Never>?
    private let url = URL.documentsDirectory.appending(path: "clockout.json")
    struct Disk: Codable { var jobs: [Job]; var shifts: [Shift]; var goal: Double; var currency: String; var checkIncludesCard: Bool }

    init(demo: Bool) {
        if demo { Demo.fill(self); return }
        if let d = try? Data(contentsOf: url), let disk = try? JSONDecoder().decode(Disk.self, from: d) {
            jobs = disk.jobs; shifts = disk.shifts; goal = disk.goal; currency = disk.currency; checkIncludesCard = disk.checkIncludesCard
        }
    }
    func save() {
        saveTask?.cancel()
        let disk = Disk(jobs: jobs, shifts: shifts, goal: goal, currency: currency, checkIncludesCard: checkIncludesCard); let u = url
        saveTask = Task.detached(priority: .utility) {
            try? await Task.sleep(for: .milliseconds(200)); if Task.isCancelled { return }
            if let d = try? JSONEncoder().encode(disk) { try? d.write(to: u, options: .atomic) }
        }
    }

    // MARK: money

    func job(_ s: Shift) -> Job? { jobs.first { $0.id == s.jobId } }
    func wages(_ s: Shift) -> Double { (job(s)?.wage ?? 0) * s.workedHours }
    func take(_ s: Shift) -> Double { wages(s) + s.tips - s.tipout }
    func rate(_ s: Shift) -> Double { s.workedHours > 0 ? take(s) / s.workedHours : 0 }
    func autoTipout(job: Job?, sales: Double, tips: Double) -> Double {
        guard let j = job else { return 0 }
        switch j.tipoutKind {
        case .none: return 0
        case .sales: return sales * j.tipoutPct / 100
        case .tips: return tips * j.tipoutPct / 100
        }
    }

    var sorted: [Shift] { shifts.sorted { $0.date == $1.date ? $0.start > $1.start : $0.date > $1.date } }
    func shifts(in month: String) -> [Shift] { shifts.filter { Day.month($0.date) == month } }
    func shifts(year: String) -> [Shift] { shifts.filter { Day.year($0.date) == year } }
    func shifts(from a: String, to b: String) -> [Shift] { shifts.filter { $0.date >= a && $0.date <= b } }
    func total(_ list: [Shift]) -> Double { list.reduce(0) { $0 + take($1) } }
    func hours(_ list: [Shift]) -> Double { list.reduce(0) { $0 + $1.workedHours } }
    func avgRate(_ list: [Shift]) -> Double { let h = hours(list); return h > 0 ? total(list) / h : 0 }

    var thisMonth: [Shift] { shifts(in: Day.month(Day.today)) }
    var thisWeek: [Shift] { let ws = Day.weekStart(Day.today); return shifts(from: ws, to: Day.add(ws, 6)) }
    var thisYear: [Shift] { shifts(year: Day.year(Day.today)) }

    /// Where this month should be by today if the goal were spread evenly.
    var pace: Double {
        let d = Day.date(Day.today)
        let n = Day.cal.range(of: .day, in: .month, for: d)?.count ?? 30
        let day = Day.cal.component(.day, from: d)
        return total(thisMonth) / Double(day) * Double(n)
    }
    func tipsVsSales(_ list: [Shift]) -> Double {
        let s = list.reduce(0) { $0 + $1.sales }; let t = list.reduce(0) { $0 + $1.tips }
        return s > 0 ? t / s : 0
    }

    struct WeekBar: Identifiable { let id: Int; let label: String; let start: String; let tips: Double; let wages: Double }
    func weekly(_ n: Int) -> [WeekBar] {
        let ws0 = Day.weekStart(Day.today)
        return (0..<n).reversed().map { i in
            let ws = Day.add(ws0, -7 * i)
            let l = shifts(from: ws, to: Day.add(ws, 6))
            let tips = l.reduce(0) { $0 + $1.tips - $1.tipout }
            let w = l.reduce(0) { $0 + wages($1) }
            return WeekBar(id: i, label: Day.date(ws).formatted(.dateTime.day().month(.abbreviated)), start: ws, tips: tips, wages: w)
        }
    }
    /// Average take-home per shift by weekday (Mon = 0).
    func weekdayAverages() -> [Double] {
        var sum = Array(repeating: 0.0, count: 7), n = Array(repeating: 0, count: 7)
        for s in shifts { let w = Day.dow(s.date); sum[w] += take(s); n[w] += 1 }
        return (0..<7).map { n[$0] > 0 ? sum[$0] / Double(n[$0]) : 0 }
    }
    struct KindStat: Identifiable { var id: String { kind }; let kind: String; let rate: Double; let count: Int; let avg: Double }
    func byKind() -> [KindStat] {
        let g = Dictionary(grouping: shifts, by: { $0.kind })
        return g.map { k, l in KindStat(kind: k, rate: avgRate(l), count: l.count, avg: total(l) / Double(max(1, l.count))) }.sorted { $0.rate > $1.rate }
    }
    var bestDay: (Int, Double)? {
        let a = weekdayAverages(); guard let m = a.max(), m > 0, let i = a.firstIndex(of: m) else { return nil }
        return (i, m)
    }

    func csv(year: String) -> String {
        var out = "date,job,shift,hours,sales,cash tips,card tips,tip-out,wages,take-home,per hour,note\n"
        for s in shifts(year: year).sorted(by: { $0.date < $1.date }) {
            let cells: [String] = [s.date, job(s)?.name ?? "", s.kind, String(format: "%.2f", s.workedHours), String(format: "%.2f", s.sales), String(format: "%.2f", s.cash), String(format: "%.2f", s.card), String(format: "%.2f", s.tipout), String(format: "%.2f", wages(s)), String(format: "%.2f", take(s)), String(format: "%.2f", rate(s)), "\"" + s.note.replacingOccurrences(of: "\"", with: "'") + "\""]
            out += cells.joined(separator: ",") + "\n"
        }
        return out
    }
}
