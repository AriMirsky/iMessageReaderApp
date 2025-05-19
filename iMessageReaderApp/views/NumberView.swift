import SwiftUI
import Charts

struct NumberView: View {
    @EnvironmentObject var store: MessagesStore
    @EnvironmentObject var contactsVM: ContactsViewModel

    enum MessageType: String, CaseIterable, Identifiable {
        case incoming = "Incoming"
        case outgoing = "Outgoing"
        case total = "Total"
        case nincoming = "Net Incoming"
        case noutgoing = "Net Outgoing"
        var id: String { rawValue }
    }

    @State private var messageType: MessageType = .incoming

    // Chart data model
    fileprivate struct ChartData: Identifiable {
        let id = UUID()
        let person: String
        let day: Date
        let count: Double
    }

    // Prepare sorted raw data and compute EMA series for top 10
    private var seriesList: [(person: String, data: [ChartData])] {
        let rawByPerson = Dictionary(
            grouping: store.lookup.flatMap { person, dayDict in
                dayDict.map { day, dirCounts in
                    let count: Double
                    switch messageType {
                    case .incoming:
                        count = Double(dirCounts[.incoming] ?? 0)
                    case .outgoing:
                        count = Double(dirCounts[.outgoing] ?? 0)
                    case .total:
                        count = Double((dirCounts[.incoming] ?? 0) + (dirCounts[.outgoing] ?? 0))
                    case .noutgoing:
                        count = Double((dirCounts[.outgoing] ?? 0) - (dirCounts[.incoming] ?? 0))
                    case .nincoming:
                        count = Double((dirCounts[.incoming] ?? 0) - (dirCounts[.outgoing] ?? 0))
                    }
                    return ChartData(person: person, day: day, count: count)
                }
            }
        ) { $0.person }

        let emaSeries = rawByPerson.map { person, points in
            let sorted = points.sorted { $0.day < $1.day }
            let data = Self.computeEMA(from: sorted, alpha: 0.1)
            return (person: person, data: data)
        }

        let withTotals = emaSeries.map { series in
            let total = series.data.reduce(0) { $0 + $1.count }
            return (person: series.person, data: series.data, total: total)
        }
        return withTotals
            .sorted { $0.total > $1.total }
            .prefix(10)
            .map { (person: $0.person, data: $0.data) }
    }

    private static func computeEMA(from series: [ChartData], alpha: Double) -> [ChartData] {
        guard let first = series.first else { return [] }
        var prev = first.count
        var out: [ChartData] = [first]
        for pt in series.dropFirst() {
            let ema = alpha * pt.count + (1 - alpha) * prev
            prev = ema
            out.append(ChartData(person: pt.person, day: pt.day, count: ema))
        }
        return out
    }

    // Slider ranges
    private var allDates: [Date] { seriesList.flatMap { $0.data.map { $0.day } } }
    private var minDate: Date { allDates.min() ?? Date() }
    private var maxDate: Date { allDates.max() ?? Date() }
    private var dateRange: ClosedRange<TimeInterval> {
        minDate.timeIntervalSinceReferenceDate...maxDate.timeIntervalSinceReferenceDate
    }
    private var maxYValue: Double { seriesList.flatMap { $0.data.map { $0.count } }.max() ?? 0 }
    private var symmetricYMax: Double { seriesList.flatMap { $0.data.map { abs($0.count) } }.max() ?? 0 }

    @State private var startTime: TimeInterval = 0
    @State private var endTime: TimeInterval = 0
    @State private var yMax: Double = 0

    private struct SeriesModel {
        let name: String
        let color: Color
        let data: [ChartData]
    }

    private var chartSeries: [SeriesModel] {
        // 1a) get the raw seriesList
        let raw = seriesList
        // 1b) extract display names
        let names = raw.map { contactsVM.displayName(for: $0.person) }
        // 1c) build a color map
        let colorMap = Dictionary(
            uniqueKeysWithValues:
                names.enumerated().map { idx, name in
                    let hue = Double(idx) / Double(names.count)
                    return (name, Color(hue: hue, saturation: 0.8, brightness: 0.8))
                }
        )
        // 1d) zip together into SeriesModel
        return zip(raw, names).map { series, displayName in
            SeriesModel(
                name: displayName,
                color: colorMap[displayName]!,
                data: series.data
            )
        }
    }
    
    private var chartColorMap: [String: Color] {
        Dictionary(uniqueKeysWithValues:
                    chartSeries.map { ($0.name, $0.color) }
        )
    }
    
    var autorefresh: some View {
        Color.clear
          .onAppear {
            startTime = dateRange.lowerBound
            endTime   = dateRange.upperBound
            yMax      = (messageType == .nincoming || messageType == .noutgoing)
                          ? symmetricYMax
                          : maxYValue
          }
          .onChange(of: messageType) { _ in
            yMax = (messageType == .nincoming || messageType == .noutgoing)
              ? symmetricYMax
              : maxYValue
          }
    }
    
    var header : some View {
        HStack {
            Text("📈 Top 10 Texters Over Time")
                .font(.title2)
            Spacer()
            Picker("Direction", selection: $messageType) {
                ForEach(MessageType.allCases) { type in
                    Text(type.rawValue).tag(type)
                }
            }
            .pickerStyle(MenuPickerStyle())
        }
        .padding(.bottom, 4)
    }
    var currentDateRange : some View {
        // Display current date range
        Text("Date Range: \(Date(timeIntervalSinceReferenceDate: startTime), style: .date) - \(Date(timeIntervalSinceReferenceDate: endTime), style: .date)")
            .font(.subheadline)
            .padding(.bottom, 8)
    }
    
    var sliders : some View {
        // Three sliders: start, end, Y max
        HStack {
            VStack {
                Text("X Start")
                Slider(value: $startTime, in: dateRange, step: 86400)
            }
            VStack {
                Text("X End")
                Slider(value: $endTime, in: dateRange, step: 86400)
            }
            VStack {
              Text("Y Max")
              Slider(
                value: $yMax,
                in: (messageType == .nincoming || messageType == .noutgoing)
                  ? (0...symmetricYMax)
                  : (0...maxYValue)
              )
            }
        }
        .padding(.vertical)
    }
    
    var mainChart : some View {
        let vm = contactsVM
        // Chart with gridlines and clipped plot area
        let displayName = { (handle: String) in
            vm.displayName(for: handle)
        }
        let inWindow: (ChartData) -> Bool = { pt in
            let t = pt.day.timeIntervalSinceReferenceDate
            return t >= startTime && t <= endTime
        }

        return Chart {
            ForEach(seriesList, id: \.person) { series in
                // filter & map out of the view builder
                let filtered = series.data.filter(inWindow)
                ForEach(filtered) { pt in
                    LineMark(
                        x: .value("Day", pt.day),
                        y: .value("EMA", pt.count)
                    )
                    .interpolationMethod(.monotone)
                    .lineStyle(StrokeStyle(lineWidth: 2))
                    .foregroundStyle(
                        by: .value("Person", displayName(series.person))
                    )
                }
            }
        }
        .chartForegroundStyleScale(
          domain: Array(chartColorMap.keys),
          range: Array(chartColorMap.values)
        )
        .chartXAxis {
            AxisMarks(values: .automatic(desiredCount: 7)) { _ in
                AxisGridLine(); AxisTick(); AxisValueLabel()
            }
        }
        .chartYAxis {
            AxisMarks(position: .leading) { _ in
                AxisGridLine(); AxisTick(); AxisValueLabel()
            }
        }
        .chartXScale(domain: Date(timeIntervalSinceReferenceDate: startTime)...Date(timeIntervalSinceReferenceDate: endTime))
        .chartYScale(domain:
          (messageType == .nincoming || messageType == .noutgoing)
            ? -yMax...yMax
            : 0...yMax
        )
        .chartPlotStyle { plotArea in
            plotArea
                .clipShape(Rectangle())
        }
        .frame(minHeight: 300)
        .padding()
    }

    var body: some View {
        VStack(alignment: .leading) {
            autorefresh
            header
            currentDateRange
            sliders
            mainChart
        }
        .padding()
    }
}

#if DEBUG
struct NumberView_Previews: PreviewProvider {
    static var previews: some View {
        NumberView()
            .environmentObject(MessagesStore.shared)
            .environmentObject(ContactsViewModel())
    }
}
#endif
