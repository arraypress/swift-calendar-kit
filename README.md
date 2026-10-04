# swift-calendar-kit

The arithmetic behind calendar screens and booking flows, and SwiftUI views built on it.

```swift
import CalendarCore

// Where each event sits on a day's timeline, overlaps side by side
let day = Timetable.layout(events, on: .now)
for placed in day.timed {
    // placed.top, .height, .leading, .width are fractions — multiply by your view's size
}

// Thirty-minute appointments every quarter hour, around what is already booked
let open = Timetable.openIntervals(hours, from: today, through: today.adding(days: 6))
let slots = Timetable.slots(length: 1800, every: 900, in: open, busy: bookings, buffer: 600)

// Can this stay be booked, and what does it cost?
let summer = Season(name: "Summer", from: try CalendarDay(year: 2026, month: 8, day: 1),
                    through: try CalendarDay(year: 2026, month: 8, day: 31), nightly: 200, weekendNightly: 250)
let rates = NightlyRates(nightly: 100, weekendNightly: 150, seasons: [summer], perStayFee: 50)
let stay = Stay(checkIn: try CalendarDay(year: 2026, month: 8, day: 27), nights: 6)
Timetable.check(stay, against: existing, rules: StayRules(minimumNights: 2))   // .available
Timetable.quote(stay, rates: rates).total   // 1250: five summer nights, two at the weekend rate, one in September, plus the fee
```

Two products. **CalendarCore** is pure logic on every Apple platform, with no UI and no
dependencies. **CalendarUI** is day, week, month, year, list and bookings-board views drawn from it, for
iPhone, iPad, Mac, Vision Pro and Apple TV.

## Three jobs

**Drawing calendars.** Month, week and year grids that start the week where the user's region
starts it. Timed events placed on a day's timeline, with overlaps in columns that widen into
free space the way Calendar.app does. All-day and multi-day events as bars stacked in lanes,
with a per-day count of what did not fit. The events touching each day, for the dots under a
month view, and day by day for a list — each event cut to the day, with "Day 2 of 5" for stays.

**Booking appointments.** Opening hours with several windows a day, closed days and holiday
exceptions, turned into real instants in a time zone. Free time, fixed-length slots and clash
checks, with a buffer between bookings. Slots across several resources — rooms, staff, tables —
naming who is free for each, or only offering a slot when enough of them are. A
week-at-a-glance summary: `Mon–Fri  09:00–17:00`, `Sat, Sun  Closed`. A bookings board: one
row per resource with its bookings in lanes, its free days, its occupancy, and the days it is
double-booked.

**Booking stays.** Nights between a check-in and a check-out day; minimum and maximum stays;
same-day turnover on or off; which days a date picker should enable for check-in, and which
check-outs once one is picked. Prices night by night: a base and weekend rate, seasons on top
(the later one wins, so Christmas can sit on winter), length-of-stay discounts and a per-stay fee.

## Repeating events

```swift
extension Meeting: RecurringEvent { var recurrence: RecurrenceRule? { rule } }

let rule = try RecurrenceRule(parsing: "FREQ=MONTHLY;BYDAY=-1FR;COUNT=12")   // or "the last friday of every month"
rule.phrase(from: firstMeeting)    // "The last Friday of every month, 12 times"
rule.rruleString                   // back to text for EventKit or a .ics feed

let items = Timetable.expand(meetings, in: nextSixMonths)   // [Occurrence<Meeting>], ready for any view
```

The rules are [`swift-chrono-kit`](../swift-chrono-kit)'s `RecurrenceRule`, and `import
CalendarCore` brings ChronoKit with it: RFC 5545 `RRULE` in and out, with the RFC's own examples
as its tests — `BYDAY` with positions, `BYMONTHDAY` from either end, `BYMONTH`, `BYSETPOS`,
`COUNT`, `UNTIL`, `WKST`, `EXDATE` and `RDATE` — plus rules written in words, and working-day
rules no `RRULE` can say. This package adds the event side: each occurrence keeps its event's
length, a range sees occurrences already running when it opens, and expansion runs in the
calendar you pass, so each user's own zone. `phrase(from:)` fills in what a rule leaves to its
first occurrence: "every week" becomes "Every Monday".

## Every call takes a calendar## Every call takes a calendar

There is no shared setting. A US calendar's week starts on Sunday and a UK one's on Monday; which
day an instant falls on depends on the zone. Pass `Calendar.current` from a view and the user
gets their own; pass a fixed one on a server and every answer is reproducible.

Chrono's own date arithmetic works in one process-wide calendar fixed to ISO weeks, which is
right for a command line and wrong for a screen that has to match the user's region — so only
its recurrence engine is used here, through the calendar parameter it takes for exactly this.

## Days are not instants

A check-in, a closure or a season is a `CalendarDay` — year, month, day, no zone. Stored as a
`Date`, "the 4th" becomes the 3rd for anyone west of where it was saved. Days convert to and
from instants only when they meet a calendar: `CalendarDay(date, in: calendar)` and
`day.date(in: calendar)`.

## Clock changes

A day is 23 or 25 hours twice a year, and nothing here pretends otherwise. Event positions and
hour lines are both fractions of the real day, so they line up: the spring day has 23 hour
lines, with no 1 AM; the autumn day reads 1 AM twice. A shop open 00:30 to 03:00 is open for an
hour and a half on the last Sunday in March.

## Bring your own events

Conform your model rather than converting it:

```swift
extension Booking: CalendarEvent {
    var start: Date { checkIn }
    var end: Date { checkOut }
    var isAllDay: Bool { true }
}
```

`end` is exclusive, as EventKit and iCalendar store it: an all-day event on the 4th ends at the
start of the 5th. An all-day event whose end is not after its start covers its start's day.
`BasicEvent` is there for when you have no model yet.

## Views

```swift
import CalendarUI

DayView(events: bookings, date: $date, title: \.title, tint: \.color)
WeekView(events: bookings, date: $date, dayCount: 3, title: \.title, tint: \.color)
MonthView(events: bookings, date: $date, style: .titles, tint: \.color, title: \.title)
YearView(events: bookings, date: $date, tint: \.color) { month in showMonth(month) }
AgendaView(events: bookings, date: $date, title: \.title, tint: \.color)
BookingBoard(resources: properties, events: stays, resourceOf: \.property, date: $date,
             name: \.self, title: \.guest, tint: \.color,
             onSelectFree: { property, day in startBooking(property, day) })
```

The month view has three styles: `.titles` draws stays as one bar across their days and lists
timed events under each date, Calendar.app style; `.pills` is coloured dots; `.labelled` is one
pill per day with your own text, such as the day's takings. The bookings board draws stays as
nights — check-in noon to check-out noon — so a turnover day shows one guest leaving and the next
arriving, shades double-booked days red, and hands back a tap on a free day as the start of a
new booking.

Tapping an event calls `onSelect`, and if details are set it shows them anchored to the event —
a popover on iPad and Mac, a sheet on iPhone. Set them once, high up, and every view uses them:

```swift
CalendarScreen()
    .calendarEventDetail { (item: Occurrence<Booking>) in
        EventDetailView(item, title: item.event.title, tint: item.event.color) {
            BookingExtras(booking: item.event)      // your own rows and buttons under the standard card
        }
    }
```

`EventDetailView` shows the title in its colour, when it happens and for how long, and — for an
occurrence — its rule in words.

### Editing

```swift
CalendarScreen()
    .calendarEditing(Item.self, selection: $selected,
        onReschedule: { item, interval, scope in store.move(item, to: interval, scope) },
        onDelete:     { item, scope in store.delete(item, scope) },
        onCreate:     { interval in store.add(interval) })
```

Inside it, click an event to select it — a ring, and a second click for its details — drag it
to another time or day, drag its bottom edge to resize it, press Delete or use the context menu
to remove it, and drag across empty time to make a new one. All-day bars drag between days. On a
touch screen a drag starts with a press and hold, so it never fights scrolling. Everything snaps
(15 minutes unless you say otherwise) and arrives as a `DateInterval`. Moving or deleting an
occurrence of a repeating event first asks "This Event, This and Following, or All Events?";
`RecurrenceRule.skipping(_:)`, `ending(before:)` and `unending` are the three edits that
answer needs. The views never change your data — your closures do. The bookings board takes
`onMove` (other days, another resource, or a new checkout from the bar's right edge) and
`onCreate` (free days swept out in a row). Repeating events carry a ↻ wherever they appear.

Each timeline view also takes a `tile` closure for your own tile; `EventTile` keeps the
standard look around any content. Measurements and colours live in one `CalendarStyle`, set with
`.calendarStyle(_:)`. Every label is written in the calendar's own locale and zone. Swiping moves
a period on touch screens and trackpads; Apple TV uses the arrow buttons.

`swift run CalendarDemo` opens every view against three months of a sample holiday-let
business: eight properties, back-to-back stays, cleans, check-ins and maintenance, generated from
a fixed seed so it looks the same every run.

## Requirements

iOS 17, macOS 14, tvOS 17, watchOS 10, visionOS 1. Swift 6. CalendarUI builds on watchOS but
its views are sized for larger screens.

## Tested

115 tests, all on fixed dates in fixed zones and locales: month grids from Sunday and Monday,
February in four rows and August in six, midnight boxes across the clock change, overlap columns
and widening, a minimum duration making short events collide, overnight events cut at midnight,
exclusive all-day ends, 23 and 25 hour lines, lanes with the long bar on top and the overflow
counted per day, free time with buffers and merged busy blocks, quarter-hourly slots around a
booking, resources by who is free, opening hours in London and across both clock changes,
week-at-a-glance in Britain and America, same-day turnover, season minimums judged by the
check-in night, picker days that stop at the next booking, prices across a season's end, overnight events
listed on both days, "Day 2 of 5" counts that do not count a midnight end, and board rows with
back-to-back stays sharing a lane while a double booking stacks and is flagged, and repeating
series: every other week on two days, the 31st skipping short months, the last day and the last
Friday of the month, leap-day birthdays, Thanksgiving, counts that count from the first occurrence,
inclusive ends, skipped days that still count, 09:00 staying 09:00 across the clock change,
a series begun in 1990 reaching 2026, RRULE text and words expanding alike, and phrases that
spell out the day a plain weekly or monthly rule leaves to its first occurrence, and edits:
drags snapped to the quarter hour, days across the clock change, sweeps in either direction,
resizes that never collapse, and the skip, end-before and unending series edits.

## Licence

MIT.
