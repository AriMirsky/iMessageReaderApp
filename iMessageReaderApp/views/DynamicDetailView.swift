import SwiftUI
import Charts

struct DynamicDetailView: View {
    @EnvironmentObject var store: MessagesStore
    @EnvironmentObject var contactsVM: ContactsViewModel
    @EnvironmentObject var readabilityVM: ReadabilityViewModel

    let itemID: String

    // Chart data model with type
    fileprivate struct ChartData: Identifiable {
        let id = UUID()
        let day: Date
        let value: Double
        let type: String
    }

    /// Computes the Exponential Moving Average (EMA) for a raw series of daily values,
    /// filling any missing days with a value of 0 for the same type.
    private func computeEMA(from rawSeries: [ChartData], alpha: Double = 0.1) -> [ChartData] {
        guard let first = rawSeries.first else { return [] }
        let calendar = Calendar.current

        // 1) Determine full date range
        let startDate = calendar.startOfDay(for: first.day)
        let endDate = calendar.startOfDay(for: rawSeries.last!.day)
        var allDates: [Date] = []
        var current = startDate
        while current <= endDate {
            allDates.append(current)
            guard let next = calendar.date(byAdding: .day, value: 1, to: current) else { break }
            current = next
        }

        // 2) Map existing values by day
        let valuesByDate: [Date: Double] = Dictionary(
            uniqueKeysWithValues: rawSeries.map { (calendar.startOfDay(for: $0.day), $0.value) }
        )

        // 3) Build zero-filled series with same type
        let filledSeries: [ChartData] = allDates.map { date in
            ChartData(
                day: date,
                value: valuesByDate[date] ?? 0.0,
                type: first.type
            )
        }

        // 4) Compute EMA on zero-padded series
        var emaSeries: [ChartData] = []
        var prevEMA = filledSeries.first!.value
        for pt in filledSeries {
            let ema = alpha * pt.value + (1 - alpha) * prevEMA
            prevEMA = ema
            emaSeries.append(
                ChartData(day: pt.day, value: ema, type: pt.type)
            )
        }
        return emaSeries
    }

    // Prepare combined EMA data
    private var chartData: [ChartData] {
        guard let dict = store.lookup[itemID] else { return [] }
        let incomingRaw = dict.map { day, counts in
            ChartData(day: day, value: Double(counts[.incoming] ?? 0), type: "Incoming")
        }.sorted { $0.day < $1.day }
        let outgoingRaw = dict.map { day, counts in
            ChartData(day: day, value: Double(counts[.outgoing] ?? 0), type: "Outgoing")
        }.sorted { $0.day < $1.day }

        let incomingEMA = computeEMA(from: incomingRaw)
        let outgoingEMA = computeEMA(from: outgoingRaw)
        return incomingEMA + outgoingEMA
    }

    // Slider ranges
    private var allDates: [Date] { chartData.map { $0.day } }
    private var dateRange: ClosedRange<TimeInterval> {
        let min = allDates.min()?.timeIntervalSinceReferenceDate ?? 0
        let max = allDates.max()?.timeIntervalSinceReferenceDate ?? 0
        return min...max
    }
    private var maxY: Double { chartData.map { $0.value }.max() ?? 1 }

    @State private var startTime: TimeInterval = 0
    @State private var endTime: TimeInterval = 0
    @State private var yMax: Double = 0
    
    fileprivate struct ChartHourData: Identifiable {
        let id     = UUID()
        let hour   : Int
        let count  : Double
        let type   : String
      }

      private var chartHourData: [ChartHourData] {
        guard let hours = store.hourlyLookup[itemID] else { return [] }
        // build two raw series
        let incoming = hours.map { hour, d in
          ChartHourData(
            hour: hour,
            count: Double(d[.incoming] ?? 0),
            type: "Incoming"
          )
        }
        let outgoing = hours.map { hour, d in
          ChartHourData(
            hour: hour,
            count: Double(d[.outgoing] ?? 0),
            type: "Outgoing"
          )
        }
        return (incoming + outgoing)
          .sorted { $0.hour < $1.hour }
      }

    var body: some View {
        let vm = contactsVM
        
        ScrollView{
            
            VStack(alignment: .leading) {
                Color.clear
                    .onAppear {
                        startTime = dateRange.lowerBound
                        endTime = dateRange.upperBound
                        yMax = maxY
                    }
                
                Text("Message Count Over Time")
                    .font(.title2).padding(.bottom, 4)
                
                HStack {
                    VStack {
                        Text("Start")
                        Slider(value: $startTime, in: dateRange, step: 86400)
                    }
                    VStack {
                        Text("End")
                        Slider(value: $endTime, in: dateRange, step: 86400)
                    }
                    VStack {
                        Text("Y Max")
                        Slider(value: $yMax, in: 0...maxY)
                    }
                }.padding(.vertical)
                
                Chart(chartData.filter { pt in
                    let t = pt.day.timeIntervalSinceReferenceDate
                    return t >= startTime && t <= endTime
                }) { pt in
                    LineMark(
                        x: .value("Day", pt.day),
                        y: .value("EMA", pt.value),
                        series: .value("Type", pt.type)
                    )
                    .foregroundStyle(by: .value("Type", pt.type))
                    .interpolationMethod(.monotone)
                    .lineStyle(StrokeStyle(lineWidth: 2))
                }
                .chartForegroundStyleScale(["Incoming": .blue, "Outgoing": .green])
                .chartXAxis { AxisMarks(values: .automatic(desiredCount: 7)) { _ in AxisGridLine(); AxisTick(); AxisValueLabel() } }
                .chartYAxis { AxisMarks(position: .leading) { _ in AxisGridLine(); AxisTick(); AxisValueLabel() } }
                .chartXScale(domain: Date(timeIntervalSinceReferenceDate: startTime)...Date(timeIntervalSinceReferenceDate: endTime))
                .chartYScale(domain: 0...yMax)
                .chartPlotStyle { $0.clipShape(Rectangle()) }
                .frame(minHeight: 300).padding()
            }
            .padding()
            
            VStack(alignment: .leading, spacing: 24) {
                // Incoming Section
                Text("Readability Scores")
                    .font(.title3).bold()
                
                // Header Row
                HStack(spacing: 16) {
                    Text("Direction")
                        .frame(width: 150, alignment: .leading)
                    Spacer()
                    Text("Grade Level")
                        .frame(width: 50, alignment: .trailing)
                    Text("Words")
                        .frame(width: 50, alignment: .trailing)
                    Text("Sentences")
                        .frame(width: 80, alignment: .trailing)
                    Text("Syllables")
                        .frame(width: 80, alignment: .trailing)
                }
                .font(.caption)
                .foregroundColor(.secondary)
                
                // Data Rows
                if let entries = readabilityVM.entryLookup[itemID] {
                    HStack(spacing: 16) {
                        Text("Incoming")
                            .frame(width: 150, alignment: .leading)
                        Spacer()
                        // grade level
                        Text(entries[.incoming].map { String(format: "%.1f", $0.score) } ?? "–")
                            .frame(width: 50, alignment: .trailing)
                        // words
                        Text("\(entries[.incoming]?.words ?? 0)")
                            .frame(width: 50, alignment: .trailing)
                        // sentences
                        Text("\(entries[.incoming]?.sentences ?? 0)")
                            .frame(width: 80, alignment: .trailing)
                        // syllables
                        Text("\(entries[.incoming]?.syllables ?? 0)")
                            .frame(width: 80, alignment: .trailing)
                    }
                    .font(.caption)
                    .foregroundColor(.secondary)
                    
                    HStack(spacing: 16) {
                        Text("Outgoing")
                            .frame(width: 150, alignment: .leading)
                        Spacer()
                        // grade level
                        Text(entries[.outgoing].map { String(format: "%.1f", $0.score) } ?? "–")
                            .frame(width: 50, alignment: .trailing)
                        // words
                        Text("\(entries[.outgoing]?.words ?? 0)")
                            .frame(width: 50, alignment: .trailing)
                        // sentences
                        Text("\(entries[.outgoing]?.sentences ?? 0)")
                            .frame(width: 80, alignment: .trailing)
                        // syllables
                        Text("\(entries[.outgoing]?.syllables ?? 0)")
                            .frame(width: 80, alignment: .trailing)
                    }
                    .font(.caption)
                    .foregroundColor(.secondary)
                } else {
                    // fallback if no data for this handle
                    Text("No readability data")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }.padding()
            
            VStack(alignment: .leading) {
              Text("Hourly Messages")
                .font(.title2)
                .padding(.bottom, 8)

              Chart(chartHourData) { pt in
                LineMark(
                  x: .value("Hour", pt.hour),
                  y: .value("Count", pt.count),
                  series: .value("Type", pt.type)
                )
                .foregroundStyle(by: .value("Type", pt.type))
                .interpolationMethod(.monotone)
                .lineStyle(StrokeStyle(lineWidth: 2))
              }
              .chartXScale(domain: 0...23)
              .chartXAxis {
                AxisMarks(values: Array(0...23)) { value in
                  AxisGridLine(); AxisTick()
                  AxisValueLabel() {
                    if let hour = value.as(Int.self) {
                      let h12 = hour % 12 == 0 ? 12 : hour % 12
                      let suffix = hour < 12 ? "am" : "pm"
                      Text("\(h12)\(suffix)")
                    }
                  }
                }
              }
              .chartYAxis {
                AxisMarks(position: .leading) {
                  AxisGridLine(); AxisValueLabel()
                }
              }
              .chartForegroundStyleScale([
                "Incoming": .blue,
                "Outgoing": .green
              ])
              .frame(height: 300)
              .padding()
            }
            .padding()
        }
    }
}
