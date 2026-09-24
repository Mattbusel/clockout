import Foundation

enum Demo {
    static func fill(_ s: Store) {
        let anchor = Job(name: "The Anchor", wage: 2.13, tipoutKind: .sales, tipoutPct: 3, color: 0)
        let cafe = Job(name: "Northside Cafe", wage: 12.50, tipoutKind: .tips, tipoutPct: 10, color: 1)
        s.jobs = [anchor, cafe]
        s.goal = 3200
        var seed: UInt64 = 11
        func rnd() -> Double { seed = seed &* 6364136223846793005 &+ 1442695040888963407; return Double((seed >> 33) % 1000) / 1000 }
        let t = Day.today
        var out: [Shift] = []
        for i in stride(from: 126, through: 0, by: -1) {
            let d = Day.add(t, -i)
            let w = Day.dow(d)
            // The Anchor: dinners Thu to Sun, a double most Saturdays, a close on Fridays.
            if [3, 4, 5, 6].contains(w) && rnd() < 0.9 {
                let weekend = w >= 4
                let double = w == 5 && rnd() < 0.5
                let kind = double ? "Double" : w == 4 ? "Close" : "Dinner"
                let start = double ? 11 * 60 : 16 * 60
                let end = double ? 23 * 60 : w == 4 ? 60 : 22 * 60 + 30
                let hrs = Double(((end - start + 1440) % 1440)) / 60
                let sales = (weekend ? 1150.0 : 780.0) * (double ? 1.7 : 1.0) * (0.8 + rnd() * 0.45)
                let tipRate = 0.16 + rnd() * 0.06
                let tips = sales * tipRate
                let cashShare = 0.18 + rnd() * 0.18
                var sh = Shift(date: d, jobId: anchor.id, kind: kind, start: start, end: end)
                sh.sales = (sales * 100).rounded() / 100
                sh.cash = (tips * cashShare).rounded()
                sh.card = ((tips * (1 - cashShare)) * 100).rounded() / 100
                sh.tipout = (sh.sales * 0.03 * 100).rounded() / 100
                _ = hrs
                if rnd() < 0.12 { sh.note = ["Big party of 12 on 14", "Slow rain night", "Two no-shows, section cut early", "Bar backed up all night"][Int(rnd() * 4) % 4] }
                out.append(sh)
            }
            // Cafe: brunch or lunch Mon to Wed, sometimes Sunday brunch.
            if ([0, 1, 2].contains(w) && rnd() < 0.7) || (w == 6 && rnd() < 0.35) {
                let brunch = w == 6 || rnd() < 0.4
                var sh = Shift(date: d, jobId: cafe.id, kind: brunch ? "Brunch" : "Lunch", start: brunch ? 8 * 60 : 10 * 60 + 30, end: brunch ? 14 * 60 + 30 : 15 * 60)
                let sales = (brunch ? 620.0 : 410.0) * (0.8 + rnd() * 0.4)
                let tips = sales * (0.14 + rnd() * 0.05)
                sh.sales = (sales * 100).rounded() / 100
                sh.cash = (tips * 0.3).rounded()
                sh.card = ((tips * 0.7) * 100).rounded() / 100
                sh.tipout = ((sh.cash + sh.card) * 0.10 * 100).rounded() / 100
                out.append(sh)
            }
        }
        // Make sure today has a shift in, so the overview reads "today".
        if !out.contains(where: { $0.date == t }) {
            var sh = Shift(date: t, jobId: anchor.id, kind: "Dinner", start: 16 * 60, end: 22 * 60 + 30)
            sh.sales = 1112; sh.cash = 61; sh.card = 144.4; sh.tipout = 33.36; sh.note = "Patio finally open"
            out.append(sh)
        }
        s.shifts = out
    }
}
