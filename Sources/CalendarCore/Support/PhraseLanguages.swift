//
//  PhraseLanguages.swift
//  CalendarCore
//
//  Repeat rules in the reader's language. ChronoKit's phrases are English
//  sentences, and a sentence is not a string to translate: the words change
//  with the weekday's gender, the case a preposition takes, whether the
//  weekdays are plural. So the common shapes — every day, every Monday and
//  Wednesday, the 1st of every month, the second Tuesday, every year on a
//  date, the fourth Thursday of November — are built per language here, and
//  anything rarer is left to ChronoKit's English.
//

import Foundation

/// The shapes a rule can be said in, once ChronoKit's parts are read.
enum PhraseShape {
    case daily(every: Int)
    case weekly(every: Int, weekdays: [Int])            // Foundation weekday numbers, in the week's order
    case monthDays([Int])                               // positive days, or [-1] for the last day
    case monthlyNth(Int, weekday: Int)                  // 1…5 or -1
    case yearlyDate(Date)
    case yearlyNth(Int, weekday: Int, month: Int)

    /// The shape of a rule, filling in what it leaves to its first
    /// occurrence; nil for anything the languages here do not cover.
    init?(_ rule: RecurrenceRule, start: Date, calendar: Calendar) {
        guard rule.bySetPos.isEmpty, rule.businessDayOrdinal == nil else { return nil }
        let ordinals = rule.byDay.compactMap(\.ordinal)
        let startWeekday = calendar.component(.weekday, from: start)
        func order(_ weekday: Int) -> Int { (weekday - calendar.firstWeekday + 7) % 7 }

        switch rule.frequency {
        case .daily where rule.byDay.isEmpty && rule.byMonthDay.isEmpty && rule.byMonth.isEmpty:
            self = .daily(every: rule.interval)
        case .weekly where ordinals.isEmpty && rule.byMonthDay.isEmpty && rule.byMonth.isEmpty:
            let days = rule.byDay.isEmpty ? [startWeekday] : rule.byDay.map(\.weekday.rawValue)
            self = .weekly(every: rule.interval, weekdays: Array(Set(days)).sorted { order($0) < order($1) })
        case .monthly where rule.interval == 1 && rule.byMonth.isEmpty:
            if rule.byDay.isEmpty {
                let days = rule.byMonthDay.isEmpty ? [calendar.component(.day, from: start)] : rule.byMonthDay
                guard days == [-1] || days.allSatisfy({ $0 > 0 }) else { return nil }
                self = .monthDays(days.sorted())
            } else if rule.byMonthDay.isEmpty, rule.byDay.count == 1, let n = rule.byDay[0].ordinal, (1...5).contains(n) || n == -1 {
                self = .monthlyNth(n, weekday: rule.byDay[0].weekday.rawValue)
            } else {
                return nil
            }
        case .yearly where rule.interval == 1:
            if rule.byDay.isEmpty && rule.byMonthDay.isEmpty
                && (rule.byMonth.isEmpty || rule.byMonth == [calendar.component(.month, from: start)]) {
                self = .yearlyDate(start)
            } else if rule.byMonthDay.isEmpty, rule.byMonth.count == 1, rule.byDay.count == 1,
                      let n = rule.byDay[0].ordinal, (1...5).contains(n) || n == -1 {
                self = .yearlyNth(n, weekday: rule.byDay[0].weekday.rawValue, month: rule.byMonth[0])
            } else {
                return nil
            }
        default:
            return nil
        }
    }
}

/// One language's way of saying each shape.
struct PhraseLanguage: Sendable {
    let daily: @Sendable (Int, Words) -> String
    let weekly: @Sendable (Int, [Int], Words) -> String
    let monthDays: @Sendable ([Int], Words) -> String
    let monthlyNth: @Sendable (Int, Int, Words) -> String
    let yearlyDate: @Sendable (String) -> String
    let yearlyNth: @Sendable (Int, Int, Int, Words) -> String
    let times: @Sendable (Int, Words) -> String
    let until: @Sendable (String) -> String
}

/// The calendar's names for things, in its language.
struct Words: Sendable {
    let calendar: Calendar

    /// "lundi", "Montag", "火曜日" — standalone, as the calendar's locale writes them.
    func weekday(_ number: Int) -> String { calendar.standaloneWeekdaySymbols[number - 1] }
    func shortWeekday(_ number: Int) -> String { calendar.shortStandaloneWeekdaySymbols[number - 1] }

    /// The month as it sits inside a date — genitive where a language has one.
    func month(_ number: Int) -> String { calendar.monthSymbols[number - 1] }

    /// "11月" where the long form is "十一月".
    func shortMonth(_ number: Int) -> String { calendar.shortMonthSymbols[number - 1] }

    /// A number in the locale's digits: ٧ in Arabic.
    func number(_ value: Int) -> String { value.formatted(.number.locale(calendar.locale ?? .current).grouping(.never)) }

    /// "a, b and c" with a language's separators.
    func list(_ items: [String], _ separator: String, _ last: String) -> String {
        items.count < 2 ? items.joined() : items.dropLast().joined(separator: separator) + last + items.last!
    }
}

enum PhraseLanguages {

    /// The rule in the calendar's language, or nil to fall back to English.
    static func describe(_ rule: RecurrenceRule, from start: Date, calendar: Calendar) -> String? {
        let code = languageCode(calendar.locale ?? .current)
        guard let language = table[code], let shape = PhraseShape(rule, start: start, calendar: calendar) else { return nil }
        let words = Words(calendar: calendar)
        var text: String
        switch shape {
        case .daily(let n): text = language.daily(n, words)
        case .weekly(let n, let days): text = language.weekly(n, days, words)
        case .monthDays(let days): text = language.monthDays(days, words)
        case .monthlyNth(let n, let weekday): text = language.monthlyNth(n, weekday, words)
        case .yearlyDate(let date):
            let formatter = DateFormatter()
            formatter.locale = calendar.locale ?? .current
            formatter.calendar = calendar
            formatter.timeZone = calendar.timeZone
            formatter.setLocalizedDateFormatFromTemplate("dMMMM")
            text = language.yearlyDate(formatter.string(from: date))
        case .yearlyNth(let n, let weekday, let month): text = language.yearlyNth(n, weekday, month, words)
        }
        if let count = rule.count { text += language.times(count, words) }
        if let until = rule.until {
            text += language.until(until.formatted(Date.FormatStyle(date: .long, time: .omitted, locale: calendar.locale ?? .current,
                                                                    calendar: calendar, timeZone: calendar.timeZone)))
        }
        return text.prefix(1).uppercased() + text.dropFirst()
    }

    /// "es", "pt-BR", "zh-Hans" — the keys of the table.
    static func languageCode(_ locale: Locale) -> String {
        let language = locale.language.languageCode?.identifier ?? "en"
        switch language {
        case "pt": return "pt-BR"
        case "zh": return locale.language.script?.identifier == "Hant" || ["TW", "HK", "MO"].contains(locale.region?.identifier) ? "zh-Hant" : "zh-Hans"
        default: return language
        }
    }

    // MARK: - Grammar helpers

    /// Russian: 1 день, 2 дня, 5 дней, 21 день.
    static func russian(_ n: Int, _ one: String, _ few: String, _ many: String) -> String {
        let tens = n % 100, units = n % 10
        if (11...14).contains(tens) { return many }
        if units == 1 { return one }
        if (2...4).contains(units) { return few }
        return many
    }

    /// Arabic: two, three to ten, eleven and up — the number in Arabic digits.
    static func arabic(_ n: Int, _ words: Words, two: String, few: String, many: String) -> String {
        if n == 2 { return two }
        return ((3...10).contains(n % 100) ? few : many).replacingOccurrences(of: "%@", with: words.number(n))
    }

    // MARK: - The languages

    static let table: [String: PhraseLanguage] = [
        "es": PhraseLanguage(
            daily: { n, _ in n == 1 ? "todos los días" : "cada \(n) días" },
            weekly: { n, days, w in
                if n == 1 && days == [2, 3, 4, 5, 6] { return "todos los días laborables" }
                let plural = days.map { day -> String in
                    let name = w.weekday(day)
                    return day == 1 || day == 7 ? name + "s" : name
                }
                let list = w.list(plural, ", ", " y ")
                return n == 1 ? "todos los \(list)" : "cada \(n) semanas, los \(list)"
            },
            monthDays: { days, w in
                days == [-1] ? "el último día de cada mes"
                    : (days.count == 1 ? "el día " : "los días ") + w.list(days.map(String.init), ", ", " y ") + " de cada mes"
            },
            monthlyNth: { n, day, w in "el \(Ordinals.es(n)) \(w.weekday(day)) de cada mes" },
            yearlyDate: { "cada año el \($0)" },
            yearlyNth: { n, day, month, w in "el \(Ordinals.es(n)) \(w.weekday(day)) de \(w.month(month)) de cada año" },
            times: { n, _ in n == 1 ? ", 1 vez" : ", \(n) veces" },
            until: { ", hasta el \($0)" }
        ),
        "fr": PhraseLanguage(
            daily: { n, _ in n == 1 ? "tous les jours" : "tous les \(n) jours" },
            weekly: { n, days, w in
                if n == 1 && days == [2, 3, 4, 5, 6] { return "du lundi au vendredi" }
                if n == 1 { return "tous les " + w.list(days.map { w.weekday($0) + "s" }, ", ", " et ") }
                return "toutes les \(n) semaines, " + w.list(days.map { "le " + w.weekday($0) }, ", ", " et ")
            },
            monthDays: { days, w in
                days == [-1] ? "le dernier jour de chaque mois"
                    : w.list(days.map { "le " + ($0 == 1 ? "1er" : String($0)) }, ", ", " et ") + " de chaque mois"
            },
            monthlyNth: { n, day, w in "le \(Ordinals.fr(n)) \(w.weekday(day)) de chaque mois" },
            yearlyDate: { "tous les ans le \($0)" },
            yearlyNth: { n, day, month, w in
                let name = w.month(month)
                let of = "aeiouéâ".contains(name.lowercased().first ?? "x") ? "d’" : "de "
                return "le \(Ordinals.fr(n)) \(w.weekday(day)) \(of)\(name) de chaque année"
            },
            times: { n, _ in ", \(n) fois" },
            until: { ", jusqu’au \($0)" }
        ),
        "de": PhraseLanguage(
            daily: { n, _ in n == 1 ? "täglich" : "alle \(n) Tage" },
            weekly: { n, days, w in
                if n == 1 && days == [2, 3, 4, 5, 6] { return "montags bis freitags" }
                let list = w.list(days.map(w.weekday), ", ", " und ")
                return n == 1 ? "jeden \(list)" : "alle \(n) Wochen am \(list)"
            },
            monthDays: { days, w in
                days == [-1] ? "am letzten Tag jedes Monats" : "jeden Monat am " + w.list(days.map { "\($0)." }, ", ", " und ")
            },
            monthlyNth: { n, day, w in "jeden \(Ordinals.de(n)) \(w.weekday(day)) im Monat" },
            yearlyDate: { "jährlich am \($0)" },
            yearlyNth: { n, day, month, w in "jedes Jahr am \(Ordinals.de(n)) \(w.weekday(day)) im \(w.month(month))" },
            times: { n, _ in ", \(n)-mal" },
            until: { ", bis \($0)" }
        ),
        "it": PhraseLanguage(
            daily: { n, _ in n == 1 ? "ogni giorno" : "ogni \(n) giorni" },
            weekly: { n, days, w in
                if n == 1 && days == [2, 3, 4, 5, 6] { return "dal lunedì al venerdì" }
                let list = w.list(days.map(w.weekday), ", ", " e ")
                return n == 1 ? "ogni \(list)" : "ogni \(n) settimane, \(list)"
            },
            monthDays: { days, w in
                days == [-1] ? "l’ultimo giorno di ogni mese"
                    : (days.count == 1 ? "il giorno " : "i giorni ") + w.list(days.map(String.init), ", ", " e ") + " di ogni mese"
            },
            monthlyNth: { n, day, w in "\(Ordinals.it(n, feminine: day == 1)) \(w.weekday(day)) di ogni mese" },
            yearlyDate: { "ogni anno il \($0)" },
            yearlyNth: { n, day, month, w in "\(Ordinals.it(n, feminine: day == 1)) \(w.weekday(day)) di \(w.month(month)) di ogni anno" },
            times: { n, _ in n == 1 ? ", 1 volta" : ", \(n) volte" },
            until: { ", fino al \($0)" }
        ),
        "pt-BR": PhraseLanguage(
            daily: { n, _ in n == 1 ? "todos os dias" : "a cada \(n) dias" },
            weekly: { n, days, w in
                if n == 1 && days == [2, 3, 4, 5, 6] { return "de segunda a sexta" }
                if n == 1 && days.count == 1 { return (days[0] == 1 || days[0] == 7 ? "todo " : "toda ") + w.weekday(days[0]) }
                let list = w.list(days.map(w.weekday), ", ", " e ")
                return n == 1 ? "toda semana, \(list)" : "a cada \(n) semanas, \(list)"
            },
            monthDays: { days, w in
                days == [-1] ? "no último dia de cada mês"
                    : (days.count == 1 ? "todo mês no dia " : "todo mês nos dias ") + w.list(days.map(String.init), ", ", " e ")
            },
            monthlyNth: { n, day, w in "\(Ordinals.pt(n, masculine: day == 1 || day == 7)) \(w.weekday(day)) de cada mês" },
            yearlyDate: { "todo ano em \($0)" },
            yearlyNth: { n, day, month, w in
                "\(Ordinals.pt(n, masculine: day == 1 || day == 7)) \(w.weekday(day)) de \(w.month(month)) de cada ano"
            },
            times: { n, _ in n == 1 ? ", 1 vez" : ", \(n) vezes" },
            until: { ", até \($0)" }
        ),
        "nl": PhraseLanguage(
            daily: { n, _ in n == 1 ? "elke dag" : "elke \(n) dagen" },
            weekly: { n, days, w in
                if n == 1 && days == [2, 3, 4, 5, 6] { return "elke werkdag" }
                let list = w.list(days.map(w.weekday), ", ", " en ")
                return n == 1 ? "elke \(list)" : "elke \(n) weken op \(list)"
            },
            monthDays: { days, w in
                days == [-1] ? "de laatste dag van elke maand" : "elke maand op de " + w.list(days.map { "\($0)e" }, ", ", " en ")
            },
            monthlyNth: { n, day, w in "elke \(Ordinals.nl(n)) \(w.weekday(day)) van de maand" },
            yearlyDate: { "elk jaar op \($0)" },
            yearlyNth: { n, day, month, w in "elke \(Ordinals.nl(n)) \(w.weekday(day)) van \(w.month(month))" },
            times: { n, _ in ", \(n) keer" },
            until: { ", tot \($0)" }
        ),
        "ja": PhraseLanguage(
            daily: { n, _ in n == 1 ? "毎日" : "\(n)日ごと" },
            weekly: { n, days, w in
                if n == 1 && days == [2, 3, 4, 5, 6] { return "平日" }
                let list = days.map(w.weekday).joined(separator: "、")
                return n == 1 ? "毎週\(list)" : "\(n)週間ごとの\(list)"
            },
            monthDays: { days, _ in days == [-1] ? "毎月末日" : "毎月" + days.map { "\($0)日" }.joined(separator: "、") },
            monthlyNth: { n, day, w in n == -1 ? "毎月最終\(w.weekday(day))" : "毎月第\(n)\(w.weekday(day))" },
            yearlyDate: { "毎年\($0)" },
            yearlyNth: { n, day, month, w in
                "毎年\(w.month(month))の" + (n == -1 ? "最終\(w.weekday(day))" : "第\(n)\(w.weekday(day))")
            },
            times: { n, _ in "、\(n)回" },
            until: { "、\($0)まで" }
        ),
        "ko": PhraseLanguage(
            daily: { n, _ in n == 1 ? "매일" : "\(n)일마다" },
            weekly: { n, days, w in
                if n == 1 && days == [2, 3, 4, 5, 6] { return "평일마다" }
                let list = days.map(w.weekday).joined(separator: ", ")
                return n == 1 ? "매주 \(list)" : "\(n)주마다 \(list)"
            },
            monthDays: { days, _ in days == [-1] ? "매월 마지막 날" : "매월 " + days.map { "\($0)일" }.joined(separator: ", ") },
            monthlyNth: { n, day, w in "매월 \(Ordinals.ko(n)) \(w.weekday(day))" },
            yearlyDate: { "매년 \($0)" },
            yearlyNth: { n, day, month, w in "매년 \(w.month(month)) \(Ordinals.ko(n)) \(w.weekday(day))" },
            times: { n, _ in ", \(n)회" },
            until: { ", \($0)까지" }
        ),
        "zh-Hans": PhraseLanguage(
            daily: { n, _ in n == 1 ? "每天" : "每\(n)天" },
            weekly: { n, days, w in
                if n == 1 && days == [2, 3, 4, 5, 6] { return "每个工作日" }
                let list = days.map(w.shortWeekday).joined(separator: "、")
                return n == 1 ? "每\(list)" : "每\(n)周的\(list)"
            },
            monthDays: { days, _ in days == [-1] ? "每月最后一天" : "每月" + days.map { "\($0)日" }.joined(separator: "、") },
            monthlyNth: { n, day, w in n == -1 ? "每月最后一个\(w.weekday(day))" : "每月第\(n)个\(w.weekday(day))" },
            yearlyDate: { "每年\($0)" },
            yearlyNth: { n, day, month, w in
                "每年\(w.shortMonth(month))的" + (n == -1 ? "最后一个\(w.weekday(day))" : "第\(n)个\(w.weekday(day))")
            },
            times: { n, _ in "，共\(n)次" },
            until: { "，直到\($0)" }
        ),
        "zh-Hant": PhraseLanguage(
            daily: { n, _ in n == 1 ? "每天" : "每\(n)天" },
            weekly: { n, days, w in
                if n == 1 && days == [2, 3, 4, 5, 6] { return "每個工作日" }
                let list = days.map(w.shortWeekday).joined(separator: "、")
                return n == 1 ? "每\(list)" : "每\(n)週的\(list)"
            },
            monthDays: { days, _ in days == [-1] ? "每月最後一天" : "每月" + days.map { "\($0)日" }.joined(separator: "、") },
            monthlyNth: { n, day, w in n == -1 ? "每月最後一個\(w.weekday(day))" : "每月第\(n)個\(w.weekday(day))" },
            yearlyDate: { "每年\($0)" },
            yearlyNth: { n, day, month, w in
                "每年\(w.month(month))的" + (n == -1 ? "最後一個\(w.weekday(day))" : "第\(n)個\(w.weekday(day))")
            },
            times: { n, _ in "，共\(n)次" },
            until: { "，直到\($0)" }
        ),
        "ru": PhraseLanguage(
            daily: { n, _ in n == 1 ? "каждый день" : "каждые \(n) \(russian(n, "день", "дня", "дней"))" },
            weekly: { n, days, w in
                if n == 1 && days == [2, 3, 4, 5, 6] { return "по будням" }
                let list = w.list(days.map { Ordinals.russianDative[$0 - 1] }, ", ", " и ")
                return n == 1 ? "по \(list)" : "каждые \(n) \(russian(n, "неделю", "недели", "недель")) по \(list)"
            },
            monthDays: { days, w in
                days == [-1] ? "в последний день каждого месяца" : "каждый месяц " + w.list(days.map { "\($0)-го" }, ", ", " и ") + " числа"
            },
            monthlyNth: { n, day, _ in "\(Ordinals.ru(n, weekday: day)) каждого месяца" },
            yearlyDate: { "каждый год \($0)" },
            yearlyNth: { n, day, month, w in "\(Ordinals.ru(n, weekday: day)) \(w.month(month)) каждого года" },
            times: { n, _ in ", \(n) \(russian(n, "раз", "раза", "раз"))" },
            until: { ", до \($0)" }
        ),
        "ar": PhraseLanguage(
            daily: { n, w in n == 1 ? "كل يوم" : arabic(n, w, two: "كل يومين", few: "كل %@ أيام", many: "كل %@ يومًا") },
            weekly: { n, days, w in
                if n == 1 && days == [2, 3, 4, 5, 6] { return "كل يوم عمل" }
                let list = w.list(days.map(w.weekday), "، ", " و")
                return n == 1 ? "أسبوعيًا يوم \(list)"
                    : arabic(n, w, two: "كل أسبوعين", few: "كل %@ أسابيع", many: "كل %@ أسبوعًا") + " يوم \(list)"
            },
            monthDays: { days, w in
                days == [-1] ? "في آخر يوم من كل شهر"
                    : (days.count == 1 ? "شهريًا في اليوم " : "شهريًا في الأيام ") + w.list(days.map(w.number), "، ", " و")
            },
            monthlyNth: { n, day, w in "في \(w.weekday(day)) \(Ordinals.ar(n)) من كل شهر" },
            yearlyDate: { "سنويًا في \($0)" },
            yearlyNth: { n, day, month, w in "في \(w.weekday(day)) \(Ordinals.ar(n)) من \(w.month(month)) كل عام" },
            times: { n, w in n == 1 ? "، مرة واحدة" : "، " + arabic(n, w, two: "مرتين", few: "%@ مرات", many: "%@ مرة") },
            until: { "، حتى \($0)" }
        ),
    ]
}

/// "second", "last" — the words for a weekday's place in its month.
enum Ordinals {

    static func es(_ n: Int) -> String { n == -1 ? "último" : ["primer", "segundo", "tercer", "cuarto", "quinto"][n - 1] }
    static func fr(_ n: Int) -> String { n == -1 ? "dernier" : ["premier", "deuxième", "troisième", "quatrième", "cinquième"][n - 1] }
    static func de(_ n: Int) -> String { n == -1 ? "letzten" : ["ersten", "zweiten", "dritten", "vierten", "fünften"][n - 1] }
    static func nl(_ n: Int) -> String { n == -1 ? "laatste" : ["eerste", "tweede", "derde", "vierde", "vijfde"][n - 1] }
    static func ko(_ n: Int) -> String { n == -1 ? "마지막" : ["첫째", "둘째", "셋째", "넷째", "다섯째"][n - 1] }
    static func ar(_ n: Int) -> String { n == -1 ? "الأخير" : ["الأول", "الثاني", "الثالث", "الرابع", "الخامس"][n - 1] }

    /// With its article: "il secondo", "l’ultimo", "la prima" (domenica is feminine).
    static func it(_ n: Int, feminine: Bool) -> String {
        if feminine { return n == -1 ? "l’ultima" : "la " + ["prima", "seconda", "terza", "quarta", "quinta"][n - 1] }
        return n == -1 ? "l’ultimo" : "il " + ["primo", "secondo", "terzo", "quarto", "quinto"][n - 1]
    }

    /// With its contraction: "na segunda" (the -feira days), "no último" (sábado, domingo).
    static func pt(_ n: Int, masculine: Bool) -> String {
        if masculine { return n == -1 ? "no último" : "no " + ["primeiro", "segundo", "terceiro", "quarto", "quinto"][n - 1] }
        return n == -1 ? "na última" : "na " + ["primeira", "segunda", "terceira", "quarta", "quinta"][n - 1]
    }

    /// Russian weekdays in the dative plural, for "по понедельникам". Sunday first.
    static let russianDative = ["воскресеньям", "понедельникам", "вторникам", "средам", "четвергам", "пятницам", "субботам"]

    /// "во вторую среду", "в последний понедельник": the preposition, the
    /// ordinal agreeing with the weekday's gender in the accusative, the weekday.
    static func ru(_ n: Int, weekday: Int) -> String {
        let accusative = ["воскресенье", "понедельник", "вторник", "среду", "четверг", "пятницу", "субботу"][weekday - 1]
        let gender = ["n", "m", "m", "f", "m", "f", "f"][weekday - 1]
        let forms: [String: [String]] = [
            "m": ["первый", "второй", "третий", "четвёртый", "пятый", "последний"],
            "f": ["первую", "вторую", "третью", "четвёртую", "пятую", "последнюю"],
            "n": ["первое", "второе", "третье", "четвёртое", "пятое", "последнее"],
        ]
        let ordinal = forms[gender]![n == -1 ? 5 : n - 1]
        let preposition = ordinal.hasPrefix("вт") ? "во" : "в"
        return "\(preposition) \(ordinal) \(accusative)"
    }
}
