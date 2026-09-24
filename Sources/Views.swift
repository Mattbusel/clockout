import SwiftUI
import Charts

// MARK: Home

struct HomeView: View {
    @Environment(Store.self) private var store
    @Environment(Router.self) private var router
    var body: some View {
        let c = store.currency
        let month = store.thisMonth, week = store.thisWeek, year = store.thisYear
        let mt = store.total(month)
        let frac = store.goal > 0 ? min(1, mt / store.goal) : 0
        let monthName = Date.now.formatted(.dateTime.month(.wide))
        let today = store.sorted.first { $0.date == Day.today }
        Page {
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 4) {
                    Text(greeting).font(.big(30)).foregroundStyle(Neon.white)
                    Text("Wages plus tips, minus tip-out, over the hours you really worked.").font(.ui(13, .medium)).foregroundStyle(Neon.grey)
                }
                Spacer()
                Button { router.settings = true } label: { Image(systemName: "gearshape.fill").font(.system(size: 16, weight: .bold)).foregroundStyle(Neon.grey).frame(width: 38, height: 38).background(Circle().fill(Neon.card)) }.buttonStyle(.plain)
            }.padding(.top, 14)

            VStack(alignment: .leading, spacing: 10) {
                Eyebrow("\(monthName) so far")
                HStack(alignment: .lastTextBaseline, spacing: 8) {
                    NeonText(text: Money.f(mt, c, cents: false), size: 40)
                    Text("of " + Money.f(store.goal, c, cents: false)).font(.money(14)).foregroundStyle(Neon.dim)
                }
                GeometryReader { g in
                    ZStack(alignment: .leading) {
                        Capsule().fill(Neon.bg2).frame(height: 10)
                        Capsule().fill(LinearGradient(colors: [Neon.amber2, Neon.amber], startPoint: .leading, endPoint: .trailing)).frame(width: max(10, g.size.width * frac), height: 10)
                            .shadow(color: Neon.amber.opacity(0.5), radius: 6)
                        Rectangle().fill(Neon.white.opacity(0.8)).frame(width: 2, height: 18).offset(x: g.size.width * monthFraction - 1)
                    }
                }.frame(height: 18)
                HStack {
                    Text("\(month.count) shifts · \(Money.h(store.hours(month)))").font(.ui(12, .semibold)).foregroundStyle(Neon.grey)
                    Spacer()
                    Text(paceLine(mt)).font(.ui(12, .heavy)).foregroundStyle(store.pace >= store.goal ? Neon.green : Neon.amber)
                }
            }.tile()

            LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 10) {
                Stat(value: Money.f(store.total(week), c, cents: false), label: "this week · \(week.count) shifts")
                Stat(value: Money.f(store.total(year), c, cents: false), label: "this year · \(year.count) shifts")
                Stat(value: Money.f(store.avgRate(month), c) + "/h", label: "real hourly, this month", color: Neon.amber)
                Stat(value: Money.pct(store.tipsVsSales(month)), label: "tips vs sales, before tip-out", color: Neon.blue)
            }

            if let t = today {
                VStack(alignment: .leading, spacing: 8) {
                    Eyebrow("Tonight's shift")
                    ShiftReceipt(shift: t)
                }
            } else {
                VStack(alignment: .leading, spacing: 6) {
                    Text("Nothing logged today.").font(.ui(16, .heavy)).foregroundStyle(Neon.white)
                    Text("Punch the amber button when you clock out. Twenty seconds, then go home.").font(.ui(13, .medium)).foregroundStyle(Neon.grey)
                }.frame(maxWidth: .infinity, alignment: .leading).tile()
            }

            VStack(alignment: .leading, spacing: 10) {
                Eyebrow("Last 12 weeks")
                WeeklyChart(bars: store.weekly(12), currency: c, height: 150)
            }.tile()

            if store.jobs.isEmpty {
                AmberButton(title: "Add your first job", icon: "plus") { router.settings = true }
            }
        }
    }
    var greeting: String { let h = Calendar.current.component(.hour, from: .now); return h < 5 ? "Late one." : h < 12 ? "Morning." : h < 17 ? "Afternoon." : "Evening." }
    var monthFraction: Double {
        let d = Date.now
        let n = Day.cal.range(of: .day, in: .month, for: d)?.count ?? 30
        return Double(Day.cal.component(.day, from: d)) / Double(n)
    }
    func paceLine(_ mt: Double) -> String {
        if mt >= store.goal { return "Goal hit" }
        return "On pace for " + Money.f(store.pace, store.currency, cents: false)
    }
}

struct WeeklyChart: View {
    let bars: [Store.WeekBar]
    let currency: String
    var height: CGFloat = 150
    var body: some View {
        Chart {
            ForEach(bars) { b in
                BarMark(x: .value("Week", b.label), y: .value("Wages", b.wages)).foregroundStyle(Neon.blue2).cornerRadius(3)
                BarMark(x: .value("Week", b.label), y: .value("Tips", b.tips)).foregroundStyle(Neon.amber).cornerRadius(3)
            }
        }
        .chartXAxis { AxisMarks(values: .automatic(desiredCount: 4)) { _ in AxisValueLabel().font(.ui(9, .bold)).foregroundStyle(Neon.dim) } }
        .chartYAxis { AxisMarks(position: .leading, values: .automatic(desiredCount: 3)) { v in
            AxisGridLine().foregroundStyle(Neon.line)
            AxisValueLabel { if let d = v.as(Double.self) { Text(Money.f(d, currency, cents: false)).font(.ui(9, .bold)).foregroundStyle(Neon.dim) } }
        } }
        .frame(height: height)
        HStack(spacing: 14) {
            Label { Text("Tips after tip-out").font(.ui(11, .heavy)).foregroundStyle(Neon.grey) } icon: { Circle().fill(Neon.amber).frame(width: 8, height: 8) }
            Label { Text("Hourly wages").font(.ui(11, .heavy)).foregroundStyle(Neon.grey) } icon: { Circle().fill(Neon.blue2).frame(width: 8, height: 8) }
        }
    }
}

/// One shift printed on receipt paper.
struct ShiftReceipt: View {
    @Environment(Store.self) private var store
    let shift: Shift
    var compact = false
    var body: some View {
        let j = store.job(shift)
        let c = store.currency
        VStack(alignment: .leading, spacing: 6) {
            HStack(alignment: .firstTextBaseline) {
                HStack(spacing: 6) {
                    Circle().fill(Neon.jobColors[(j?.color ?? 0) % Neon.jobColors.count]).frame(width: 8, height: 8)
                    Text(j?.name ?? "No job").font(.ui(13, .heavy)).foregroundStyle(Neon.ink)
                    Text(shift.kind.uppercased()).font(.ui(10, .heavy)).tracking(1).foregroundStyle(Neon.ink2)
                }
                Spacer()
                Text(Day.short(shift.date)).font(.money(11, .bold)).foregroundStyle(Neon.ink2)
            }
            Text(timeLine).font(.money(11, .medium)).foregroundStyle(Neon.ink2)
            DottedLine().padding(.vertical, 2)
            if !compact {
                row("Sales", Money.f(shift.sales, c))
                row("Cash tips", Money.f(shift.cash, c))
                row("Card tips", Money.f(shift.card, c))
                row("Tip-out", "-" + Money.f(shift.tipout, c))
                row("Wages " + Money.f(j?.wage ?? 0, c) + "/h", Money.f(store.wages(shift), c))
                DottedLine().padding(.vertical, 2)
            }
            HStack(alignment: .lastTextBaseline) {
                Text("TAKE-HOME").font(.ui(11, .heavy)).tracking(1.5).foregroundStyle(Neon.ink)
                Spacer()
                Text(Money.f(store.rate(shift), c) + "/h").font(.money(12, .bold)).foregroundStyle(Neon.ink2)
                Text(Money.f(store.take(shift), c)).font(.money(20, .heavy)).foregroundStyle(Neon.ink)
            }
            if !shift.note.isEmpty && !compact { Text(shift.note).font(.ui(12, .medium)).italic().foregroundStyle(Neon.ink2).padding(.top, 2) }
        }.receipt()
    }
    var timeLine: String {
        if shift.useHours { return Money.h(shift.workedHours) }
        return Day.clock(shift.start) + " to " + Day.clock(shift.end) + " · " + Money.h(shift.workedHours)
    }
    func row(_ l: String, _ v: String) -> some View {
        HStack { Text(l).font(.money(12)).foregroundStyle(Neon.ink2); Spacer(); Text(v).font(.money(12, .bold)).foregroundStyle(Neon.ink) }
    }
}

struct DottedLine: View {
    var body: some View {
        Line().stroke(style: StrokeStyle(lineWidth: 1, dash: [3, 3])).foregroundStyle(Neon.ink2.opacity(0.5)).frame(height: 1)
    }
    struct Line: Shape { func path(in r: CGRect) -> Path { var p = Path(); p.move(to: CGPoint(x: r.minX, y: r.midY)); p.addLine(to: CGPoint(x: r.maxX, y: r.midY)); return p } }
}

// MARK: Shifts

struct ShiftsView: View {
    @Environment(Store.self) private var store
    @Environment(Router.self) private var router
    var body: some View {
        @Bindable var router = router
        let list = store.sorted.filter { (router.shiftFilterJob == nil || $0.jobId == router.shiftFilterJob) && (router.shiftMonth == nil || Day.month($0.date) == router.shiftMonth) }
        let weeks = groupedWeeks(list)
        let months = Array(Set(store.shifts.map { Day.month($0.date) })).sorted(by: >)
        VStack(spacing: 0) {
            VStack(alignment: .leading, spacing: 10) {
                HStack(alignment: .lastTextBaseline) {
                    Text("Shifts.").font(.big(30)).foregroundStyle(Neon.white)
                    Spacer()
                    Text("\(list.count) · " + Money.f(store.total(list), store.currency, cents: false)).font(.money(13, .bold)).foregroundStyle(Neon.grey)
                }
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 6) {
                        Chip(text: "All jobs", on: router.shiftFilterJob == nil) { router.shiftFilterJob = nil }
                        ForEach(store.jobs) { j in Chip(text: j.name, on: router.shiftFilterJob == j.id, color: Neon.jobColors[j.color % Neon.jobColors.count]) { router.shiftFilterJob = j.id } }
                        Divider().frame(height: 20)
                        Chip(text: "Any month", on: router.shiftMonth == nil, color: Neon.blue) { router.shiftMonth = nil }
                        ForEach(months, id: \.self) { m in Chip(text: monthLabel(m), on: router.shiftMonth == m, color: Neon.blue) { router.shiftMonth = m } }
                    }
                }
            }.padding(.horizontal, 16).padding(.top, 22).padding(.bottom, 8)
            List {
                ForEach(weeks, id: \.start) { w in
                    Section {
                        ForEach(w.shifts) { s in
                            ShiftReceipt(shift: s, compact: true)
                                .listRowBackground(Color.clear).listRowSeparator(.hidden).listRowInsets(EdgeInsets(top: 4, leading: 16, bottom: 8, trailing: 16))
                                .contentShape(Rectangle())
                                .onTapGesture { router.draft.load(s, store); router.adding = true }
                                .swipeActions(edge: .trailing) {
                                    Button(role: .destructive) { store.shifts.removeAll { $0.id == s.id }; store.save() } label: { Label("Delete", systemImage: "trash") }
                                    Button { router.draft.load(s, store); router.adding = true } label: { Label("Edit", systemImage: "pencil") }.tint(Neon.blue2)
                                }
                        }
                    } header: {
                        HStack {
                            Text(weekLabel(w.start)).font(.ui(11, .heavy)).tracking(2).foregroundStyle(Neon.dim)
                            Spacer()
                            Text(Money.f(store.total(w.shifts), store.currency, cents: false) + " · " + Money.h(store.hours(w.shifts))).font(.money(11, .bold)).foregroundStyle(Neon.grey)
                        }.textCase(nil).padding(.horizontal, 0)
                    }
                }
                if list.isEmpty {
                    Text(store.shifts.isEmpty ? "No shifts yet. Punch the amber button after your next one." : "Nothing matches those filters.").font(.ui(14, .medium)).foregroundStyle(Neon.grey)
                        .listRowBackground(Color.clear).listRowSeparator(.hidden)
                }
                Color.clear.frame(height: 100).listRowBackground(Color.clear).listRowSeparator(.hidden)
            }
            .listStyle(.plain).scrollContentBackground(.hidden).environment(\.defaultMinListHeaderHeight, 0)
        }
    }
    struct Week { let start: String; let shifts: [Shift] }
    func groupedWeeks(_ l: [Shift]) -> [Week] {
        let g = Dictionary(grouping: l, by: { Day.weekStart($0.date) })
        return g.keys.sorted(by: >).map { Week(start: $0, shifts: g[$0]!) }
    }
    func weekLabel(_ ws: String) -> String {
        if ws == Day.weekStart(Day.today) { return "This week" }
        if ws == Day.add(Day.weekStart(Day.today), -7) { return "Last week" }
        return "Week of " + Day.date(ws).formatted(.dateTime.month(.abbreviated).day())
    }
    func monthLabel(_ m: String) -> String { Day.date(m + "-01").formatted(.dateTime.month(.abbreviated).year(.twoDigits)) }
}

// MARK: Insights

struct InsightsView: View {
    @Environment(Store.self) private var store
    var body: some View {
        let c = store.currency
        let wd = store.weekdayAverages()
        let mx = max(1, wd.max() ?? 1)
        let kinds = store.byKind()
        let all = store.shifts
        Page {
            VStack(alignment: .leading, spacing: 4) {
                Text("Insights.").font(.big(30)).foregroundStyle(Neon.white)
                Text("Which nights pay, which do not, and what you really make an hour.").font(.ui(13, .medium)).foregroundStyle(Neon.grey)
            }.padding(.top, 14)
            LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 10) {
                Stat(value: Money.f(store.avgRate(all), c) + "/h", label: "real hourly, all time", color: Neon.amber)
                Stat(value: Money.f(store.total(all) / Double(max(1, all.count)), c, cents: false), label: "average take-home per shift")
                if let b = store.bestDay { Stat(value: Day.names[b.0], label: Money.f(b.1, c, cents: false) + " average · best day", color: Neon.blue) }
                if let k = kinds.first { Stat(value: k.kind, label: Money.f(k.rate, c) + "/h · best shift type", color: Neon.blue) }
            }
            VStack(alignment: .leading, spacing: 10) {
                Eyebrow("Average take-home by day")
                HStack(alignment: .bottom, spacing: 8) {
                    ForEach(0..<7, id: \.self) { i in
                        VStack(spacing: 4) {
                            Text(Money.f(wd[i], c, cents: false)).font(.money(9, .bold)).foregroundStyle(Neon.grey).lineLimit(1).minimumScaleFactor(0.7)
                            RoundedRectangle(cornerRadius: 5).fill(wd[i] >= mx * 0.9 ? Neon.amber : Neon.blue2).frame(height: max(4, 90 * wd[i] / mx))
                            Text(Day.names[i]).font(.ui(10, .heavy)).foregroundStyle(Neon.dim)
                        }.frame(maxWidth: .infinity)
                    }
                }.frame(height: 130, alignment: .bottom)
            }.tile()
            VStack(alignment: .leading, spacing: 10) {
                Eyebrow("By shift type · take-home an hour")
                let top = max(1, kinds.first?.rate ?? 1)
                ForEach(kinds) { k in
                    HStack(spacing: 10) {
                        Text(k.kind).font(.ui(13, .heavy)).foregroundStyle(Neon.white).frame(width: 64, alignment: .leading)
                        GeometryReader { g in
                            Capsule().fill(Neon.bg2).frame(height: 8).overlay(alignment: .leading) { Capsule().fill(Neon.blue).frame(width: max(8, g.size.width * k.rate / top), height: 8) }
                        }.frame(height: 8)
                        Text(Money.f(k.rate, c)).font(.money(12, .bold)).foregroundStyle(Neon.green).frame(width: 64, alignment: .trailing)
                        Text("\(k.count)").font(.money(11)).foregroundStyle(Neon.dim).frame(width: 26, alignment: .trailing)
                    }.padding(.vertical, 4)
                }
                if kinds.isEmpty { Text("Log a few shifts and this fills in.").font(.ui(13, .medium)).foregroundStyle(Neon.grey) }
            }.tile()
            VStack(alignment: .leading, spacing: 10) {
                Eyebrow("Last 16 weeks")
                WeeklyChart(bars: store.weekly(16), currency: c, height: 170)
            }.tile()
            VStack(alignment: .leading, spacing: 10) {
                Eyebrow("By job")
                ForEach(store.jobs) { j in
                    let l = all.filter { $0.jobId == j.id }
                    HStack {
                        Circle().fill(Neon.jobColors[j.color % Neon.jobColors.count]).frame(width: 8, height: 8)
                        Text(j.name).font(.ui(13, .heavy)).foregroundStyle(Neon.white)
                        Spacer()
                        Text("\(l.count) shifts").font(.money(11)).foregroundStyle(Neon.dim)
                        Text(Money.f(store.avgRate(l), c) + "/h").font(.money(12, .bold)).foregroundStyle(Neon.amber).frame(width: 78, alignment: .trailing)
                    }.padding(.vertical, 4)
                }
            }.tile()
        }
    }
}

// MARK: Money (paycheck + tax)

struct MoneyView: View {
    @Environment(Router.self) private var router
    var body: some View {
        @Bindable var router = router
        Page {
            Text("Money.").font(.big(30)).foregroundStyle(Neon.white).padding(.top, 14)
            Picker("", selection: $router.moneyPage) { Text("Paycheck check").tag(0); Text("Tax year").tag(1) }.pickerStyle(.segmented)
            if router.moneyPage == 0 { PaycheckView() } else { TaxView() }
        }
    }
}

struct PaycheckView: View {
    @Environment(Store.self) private var store
    @State private var from: Date = Calendar.current.date(byAdding: .day, value: -14, to: .now) ?? .now
    @State private var to: Date = .now
    @State private var check = ""
    var body: some View {
        @Bindable var store = store
        let c = store.currency
        let list = store.shifts(from: Day.key(from), to: Day.key(to)).sorted { $0.date < $1.date }
        let wages = list.reduce(0) { $0 + store.wages($1) }
        let card = list.reduce(0) { $0 + $1.card }
        let expected = wages + (store.checkIncludesCard ? card : 0)
        let got = Draft.val(check)
        let diff = got - expected
        VStack(alignment: .leading, spacing: 10) {
            Text("Does the check match your shifts?").font(.ui(16, .heavy)).foregroundStyle(Neon.white)
            Text("Pick the pay period. Clockout adds up the hours you logged at each job's wage, plus card tips if they come on the check.").font(.ui(13, .medium)).foregroundStyle(Neon.grey)
            HStack(spacing: 8) {
                DatePicker("From", selection: $from, displayedComponents: .date).labelsHidden().tint(Neon.amber)
                Text("to").font(.ui(12, .heavy)).foregroundStyle(Neon.dim)
                DatePicker("To", selection: $to, displayedComponents: .date).labelsHidden().tint(Neon.amber)
            }
            Toggle(isOn: $store.checkIncludesCard) { Text("Card tips are paid on the check").font(.ui(14, .semibold)).foregroundStyle(Neon.white) }.tint(Neon.amber)
                .onChange(of: store.checkIncludesCard) { store.save() }
            MoneyField(label: "What the check says", text: $check, prefix: c)
        }.tile()
        VStack(alignment: .leading, spacing: 8) {
            Eyebrow("Expected for \(list.count) shifts · \(Money.h(store.hours(list)))")
            line("Hourly wages", Money.f(wages, c))
            if store.checkIncludesCard { line("Card tips", Money.f(card, c)) }
            Divider().overlay(Neon.line2)
            HStack { Text("Should be").font(.ui(14, .heavy)).foregroundStyle(Neon.white); Spacer(); NeonText(text: Money.f(expected, c), size: 24) }
            if got > 0 {
                HStack {
                    Text(abs(diff) < 1 ? "Matches" : diff < 0 ? "Short by" : "Over by").font(.ui(14, .heavy)).foregroundStyle(abs(diff) < 1 ? Neon.green : diff < 0 ? Neon.red : Neon.blue)
                    Spacer()
                    Text(Money.f(abs(diff), c)).font(.money(20, .heavy)).foregroundStyle(abs(diff) < 1 ? Neon.green : diff < 0 ? Neon.red : Neon.blue)
                }
                if diff < -1 { Text("Before taxes and deductions. If gross pay on the stub is short, take this list to your manager.").font(.ui(12, .medium)).foregroundStyle(Neon.grey) }
            }
        }.tile()
        VStack(alignment: .leading, spacing: 6) {
            Eyebrow("Shifts in the period")
            ForEach(list) { s in
                HStack {
                    Text(Day.short(s.date)).font(.money(11, .bold)).foregroundStyle(Neon.grey).frame(width: 96, alignment: .leading)
                    Text((store.job(s)?.name ?? "") + " · " + s.kind).font(.ui(12, .semibold)).foregroundStyle(Neon.white).lineLimit(1)
                    Spacer()
                    Text(Money.h(s.workedHours)).font(.money(11)).foregroundStyle(Neon.dim)
                    Text(Money.f(store.wages(s), c)).font(.money(12, .bold)).foregroundStyle(Neon.white).frame(width: 70, alignment: .trailing)
                }.padding(.vertical, 3)
            }
            if list.isEmpty { Text("No shifts logged between those dates.").font(.ui(13, .medium)).foregroundStyle(Neon.grey) }
        }.tile()
    }
    func line(_ l: String, _ v: String) -> some View { HStack { Text(l).font(.ui(13, .semibold)).foregroundStyle(Neon.grey); Spacer(); Text(v).font(.money(13, .bold)).foregroundStyle(Neon.white) } }
}

struct TaxView: View {
    @Environment(Store.self) private var store
    @State private var year = Day.year(Day.today)
    var body: some View {
        let c = store.currency
        let years = Array(Set(store.shifts.map { Day.year($0.date) })).sorted(by: >)
        let list = store.shifts(year: year)
        let cash = list.reduce(0) { $0 + $1.cash }, card = list.reduce(0) { $0 + $1.card }, tipout = list.reduce(0) { $0 + $1.tipout }
        let wages = list.reduce(0) { $0 + store.wages($1) }
        let csv = store.csv(year: year)
        HStack(spacing: 6) { ForEach(years.isEmpty ? [year] : years, id: \.self) { y in Chip(text: y, on: year == y) { year = y } } }
        VStack(alignment: .leading, spacing: 10) {
            Eyebrow("\(year) · \(list.count) shifts · \(Money.h(store.hours(list)))")
            HStack(alignment: .lastTextBaseline) { Text("Tips after tip-out").font(.ui(14, .heavy)).foregroundStyle(Neon.white); Spacer(); NeonText(text: Money.f(cash + card - tipout, c), size: 26) }
            Divider().overlay(Neon.line2)
            line("Cash tips", Money.f(cash, c)); line("Card tips", Money.f(card, c)); line("Tip-out paid", "-" + Money.f(tipout, c)); line("Hourly wages", Money.f(wages, c))
            Divider().overlay(Neon.line2)
            HStack { Text("Total take-home").font(.ui(14, .heavy)).foregroundStyle(Neon.white); Spacer(); Text(Money.f(store.total(list), c)).font(.money(20, .heavy)).foregroundStyle(Neon.amber) }
            Text("Tips are taxable income, cash included. Card tips usually appear on your W-2 already; cash tips are yours to report. This is your own record, not tax advice.").font(.ui(12, .medium)).foregroundStyle(Neon.grey)
        }.tile()
        VStack(alignment: .leading, spacing: 8) {
            Eyebrow("By job")
            ForEach(store.jobs) { j in
                let l = list.filter { $0.jobId == j.id }
                if !l.isEmpty {
                    HStack {
                        Circle().fill(Neon.jobColors[j.color % Neon.jobColors.count]).frame(width: 8, height: 8)
                        Text(j.name).font(.ui(13, .heavy)).foregroundStyle(Neon.white)
                        Spacer()
                        Text("tips " + Money.f(l.reduce(0) { $0 + $1.tips - $1.tipout }, c, cents: false)).font(.money(11)).foregroundStyle(Neon.grey)
                        Text(Money.f(store.total(l), c, cents: false)).font(.money(12, .bold)).foregroundStyle(Neon.white).frame(width: 74, alignment: .trailing)
                    }.padding(.vertical, 3)
                }
            }
        }.tile()
        VStack(alignment: .leading, spacing: 6) {
            Eyebrow("By month")
            ForEach(1...12, id: \.self) { m in
                let key = year + String(format: "-%02d", m)
                let l = list.filter { Day.month($0.date) == key }
                if !l.isEmpty {
                    HStack {
                        Text(Day.date(key + "-01").formatted(.dateTime.month(.wide))).font(.ui(13, .semibold)).foregroundStyle(Neon.white).frame(width: 90, alignment: .leading)
                        Text("\(l.count) shifts").font(.money(11)).foregroundStyle(Neon.dim)
                        Spacer()
                        Text("cash " + Money.f(l.reduce(0) { $0 + $1.cash }, c, cents: false)).font(.money(11)).foregroundStyle(Neon.grey)
                        Text(Money.f(store.total(l), c, cents: false)).font(.money(12, .bold)).foregroundStyle(Neon.white).frame(width: 70, alignment: .trailing)
                    }.padding(.vertical, 3)
                }
            }
        }.tile()
        ShareLink(item: csv, preview: SharePreview("Clockout \(year).csv")) {
            HStack(spacing: 8) { Image(systemName: "square.and.arrow.up").font(.system(size: 15, weight: .black)); Text("Export \(year) as CSV").font(.ui(15, .heavy)) }
                .foregroundStyle(Neon.bg).frame(maxWidth: .infinity).padding(.vertical, 15)
                .background(RoundedRectangle(cornerRadius: 14, style: .continuous).fill(Neon.amber))
        }
    }
    func line(_ l: String, _ v: String) -> some View { HStack { Text(l).font(.ui(13, .semibold)).foregroundStyle(Neon.grey); Spacer(); Text(v).font(.money(13, .bold)).foregroundStyle(Neon.white) } }
}

// MARK: Add shift (the punch clock)

struct AddShiftView: View {
    @Environment(Store.self) private var store
    @Environment(Router.self) private var router
    @Environment(\.dismiss) private var dismiss
    var body: some View {
        @Bindable var d = router.draft
        let c = store.currency
        let editing = d.editingId != nil
        ZStack {
            DinerBackground()
            ScrollView(showsIndicators: false) {
                VStack(alignment: .leading, spacing: 16) {
                    HStack(alignment: .firstTextBaseline) {
                        VStack(alignment: .leading, spacing: 2) {
                            Text(editing ? "Edit shift." : "Clocking out.").font(.big(30)).foregroundStyle(Neon.white)
                            Text(editing ? "Change anything, then save." : "Twenty seconds. Then go home.").font(.ui(13, .medium)).foregroundStyle(Neon.grey)
                        }
                        Spacer()
                        Button { dismiss() } label: { Image(systemName: "xmark").font(.system(size: 14, weight: .black)).foregroundStyle(Neon.grey).frame(width: 36, height: 36).background(Circle().fill(Neon.card)) }.buttonStyle(.plain)
                    }.padding(.top, 18)

                    // Live punch card
                    VStack(alignment: .leading, spacing: 6) {
                        HStack(alignment: .lastTextBaseline) {
                            Eyebrow("Take-home")
                            Spacer()
                            Text(Money.h(d.workedHours)).font(.money(12, .bold)).foregroundStyle(Neon.grey)
                        }
                        HStack(alignment: .lastTextBaseline, spacing: 10) {
                            NeonText(text: Money.f(d.take(store), c), size: 40)
                            Spacer()
                            VStack(alignment: .trailing, spacing: 0) {
                                Text(Money.f(d.rate(store), c) + "/h").font(.money(18, .heavy)).foregroundStyle(Neon.blue)
                                Text("real hourly").font(.ui(10, .heavy)).foregroundStyle(Neon.dim)
                            }
                        }
                    }.tile()

                    if store.jobs.count > 1 {
                        VStack(alignment: .leading, spacing: 8) {
                            Eyebrow("Job")
                            HStack(spacing: 6) { ForEach(Array(store.jobs.enumerated()), id: \.element.id) { i, j in Chip(text: j.name, on: d.jobIndex == i, color: Neon.jobColors[j.color % Neon.jobColors.count]) { d.jobIndex = i } } }
                        }
                    } else if store.jobs.isEmpty {
                        Text("Add a job first (the gear on the home screen) so wages and tip-out can be worked out.").font(.ui(13, .medium)).foregroundStyle(Neon.red).tile()
                    }
                    VStack(alignment: .leading, spacing: 8) {
                        Eyebrow("Shift")
                        ScrollView(.horizontal, showsIndicators: false) { HStack(spacing: 6) { ForEach(Draft.kinds, id: \.self) { k in Chip(text: k, on: d.kind == k) { d.kind = k } } } }
                        HStack {
                            DatePicker("Day", selection: $d.date, displayedComponents: .date).labelsHidden().tint(Neon.amber)
                            Spacer()
                            Toggle(isOn: $d.useHours) { Text("Just hours").font(.ui(13, .heavy)).foregroundStyle(Neon.grey) }.tint(Neon.blue).fixedSize()
                        }
                        if d.useHours {
                            MoneyField(label: "Hours worked", text: $d.hours, prefix: "", hint: "6.5")
                        } else {
                            HStack(spacing: 8) {
                                VStack(alignment: .leading, spacing: 4) { Eyebrow("Clock in"); DatePicker("", selection: $d.start, displayedComponents: .hourAndMinute).labelsHidden().tint(Neon.amber) }
                                Spacer()
                                VStack(alignment: .trailing, spacing: 4) { Eyebrow("Clock out"); DatePicker("", selection: $d.end, displayedComponents: .hourAndMinute).labelsHidden().tint(Neon.amber) }
                            }
                            if Draft.minutes(d.end) <= Draft.minutes(d.start) { Text("Past midnight, counted as the next day.").font(.ui(11, .heavy)).foregroundStyle(Neon.blue) }
                        }
                    }.tile()
                    MoneyField(label: "Sales", text: $d.sales, prefix: c)
                    HStack(spacing: 10) {
                        MoneyField(label: "Cash tips", text: $d.cash, prefix: c)
                        MoneyField(label: "Card tips", text: $d.card, prefix: c)
                    }
                    VStack(alignment: .leading, spacing: 4) {
                        MoneyField(label: "Tip-out", text: tipoutBinding(d), prefix: c)
                        Text(tipoutHint(d)).font(.ui(11, .heavy)).foregroundStyle(Neon.dim).padding(.leading, 4)
                    }
                    TextField("Note (big party, slow night...)", text: $d.note).font(.ui(14, .semibold)).foregroundStyle(Neon.white).padding(12)
                        .background(RoundedRectangle(cornerRadius: 14, style: .continuous).fill(Neon.bg2)).overlay(RoundedRectangle(cornerRadius: 14, style: .continuous).strokeBorder(Neon.line2))
                    AmberButton(title: editing ? "Save changes" : "Punch out", icon: editing ? "checkmark" : "clock.badge.checkmark") { save() }
                    if editing {
                        GhostButton(title: "Delete this shift", icon: "trash") { store.shifts.removeAll { $0.id == d.editingId }; store.save(); dismiss() }
                    }
                    Color.clear.frame(height: 30)
                }.padding(.horizontal, 16)
            }
        }
        .scrollDismissesKeyboard(.interactively)
    }
    func tipoutBinding(_ d: Draft) -> Binding<String> {
        Binding(get: { d.tipoutTouched ? d.tipout : Draft.num((d.autoTipout(store) * 100).rounded() / 100) },
                set: { d.tipout = $0; d.tipoutTouched = true })
    }
    func tipoutHint(_ d: Draft) -> String {
        guard let j = d.job(store) else { return "" }
        if d.tipoutTouched { return "Typed by hand" }
        switch j.tipoutKind {
        case .none: return "No tip-out at \(j.name)"
        case .sales: return String(format: "%.1f%% of sales at %@ · edit if tonight was different", j.tipoutPct, j.name)
        case .tips: return String(format: "%.0f%% of tips at %@ · edit if tonight was different", j.tipoutPct, j.name)
        }
    }
    func save() {
        guard let s = router.draft.build(store) else { return }
        if let i = store.shifts.firstIndex(where: { $0.id == s.id }) { store.shifts[i] = s } else { store.shifts.append(s) }
        store.save()
        UINotificationFeedbackGenerator().notificationOccurred(.success)
        dismiss()
    }
}

// MARK: Settings (jobs, goal, currency)

struct SettingsView: View {
    @Environment(Store.self) private var store
    @Environment(\.dismiss) private var dismiss
    @State private var goal = ""
    var body: some View {
        @Bindable var store = store
        ScrollView(showsIndicators: false) {
            VStack(alignment: .leading, spacing: 18) {
                HStack { Text("Jobs & settings.").font(.big(26)).foregroundStyle(Neon.white); Spacer(); Button("Done") { dismiss() }.font(.ui(15, .heavy)).foregroundStyle(Neon.amber) }.padding(.top, 22)
                VStack(alignment: .leading, spacing: 10) {
                    Eyebrow("Jobs")
                    ForEach($store.jobs) { $j in JobEditor(job: $j) }
                    GhostButton(title: "Add a job", icon: "plus") { store.jobs.append(Job(name: "New job", color: store.jobs.count % Neon.jobColors.count)); store.save() }
                }
                VStack(alignment: .leading, spacing: 10) {
                    Eyebrow("Monthly goal")
                    MoneyField(label: "Take-home you are aiming for each month", text: $goal, prefix: store.currency)
                        .onChange(of: goal) { store.goal = Draft.val(goal); store.save() }
                }
                VStack(alignment: .leading, spacing: 10) {
                    Eyebrow("Currency symbol")
                    HStack(spacing: 6) { ForEach(["$", "£", "€", "C$", "A$", "¥"], id: \.self) { s in Chip(text: s, on: store.currency == s) { store.currency = s; store.save() } } }
                }
                Text("Everything stays on this phone. Nothing is uploaded anywhere.").font(.ui(12, .medium)).foregroundStyle(Neon.dim)
            }.padding(18)
        }
        .onAppear { goal = Draft.num(store.goal) }
    }
}

struct JobEditor: View {
    @Environment(Store.self) private var store
    @Binding var job: Job
    @State private var wage = ""
    @State private var pct = ""
    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                TextField("Job name", text: $job.name).font(.ui(17, .heavy)).foregroundStyle(Neon.white).onChange(of: job.name) { store.save() }
                Spacer()
                HStack(spacing: 6) { ForEach(0..<Neon.jobColors.count, id: \.self) { i in Circle().fill(Neon.jobColors[i]).frame(width: 18, height: 18).overlay(Circle().strokeBorder(Neon.white, lineWidth: job.color == i ? 2 : 0)).onTapGesture { job.color = i; store.save() } } }
                Button { store.jobs.removeAll { $0.id == job.id }; store.save() } label: { Image(systemName: "trash").font(.system(size: 13, weight: .bold)).foregroundStyle(Neon.dim) }.buttonStyle(.plain).padding(.leading, 6)
            }
            MoneyField(label: "Hourly wage", text: $wage, prefix: store.currency, hint: "2.13").onChange(of: wage) { job.wage = Draft.val(wage); store.save() }
            VStack(alignment: .leading, spacing: 6) {
                Eyebrow("Tip-out rule")
                Picker("", selection: $job.tipoutKind) { Text("None").tag(TipoutKind.none); Text("% of sales").tag(TipoutKind.sales); Text("% of tips").tag(TipoutKind.tips) }.pickerStyle(.segmented).onChange(of: job.tipoutKind) { store.save() }
                if job.tipoutKind != .none { MoneyField(label: "Percent", text: $pct, prefix: "%", hint: "3").onChange(of: pct) { job.tipoutPct = Draft.val(pct); store.save() } }
            }
        }.tile()
        .onAppear { wage = Draft.num(job.wage); pct = Draft.num(job.tipoutPct) }
    }
}
