import SwiftUI
import Charts

struct TimeOfDayView: View {
    @EnvironmentObject var store: MessagesStore
    @EnvironmentObject var contactsVM: ContactsViewModel
    
    enum MessageType: String, CaseIterable, Identifiable {
        case incoming  = "Incoming"
        case outgoing  = "Outgoing"
        case total     = "Total"
        case nincoming = "Net Incoming"
        case noutgoing = "Net Outgoing"
        var id: String { rawValue }
    }
    @State private var messageType: MessageType = .incoming
    
    fileprivate struct ChartData: Identifiable {
        let id     = UUID()
        let person : String
        let hour   : Int
        let count  : Double
    }
    
    private var seriesList: [(person: String, data: [ChartData])] {
        let points = store.hourlyLookup.flatMap { handle, hours in
            hours.map { hour, d in
                let c: Double
                switch messageType {
                case .incoming:  c = Double(d[.incoming] ?? 0)
                case .outgoing:  c = Double(d[.outgoing] ?? 0)
                case .total:     c = Double((d[.incoming] ?? 0) + (d[.outgoing] ?? 0))
                case .nincoming: c = Double((d[.incoming] ?? 0) - (d[.outgoing] ?? 0))
                case .noutgoing: c = Double((d[.outgoing] ?? 0) - (d[.incoming] ?? 0))
                }
                return ChartData(person: handle, hour: hour, count: c)
            }
        }
        let grouped = Dictionary(grouping: points, by: \.person)
        let ranked = grouped.map { handle, pts in
            (handle: handle,
             total: pts.reduce(0) { $0 + $1.count },
             data: pts.sorted { $0.hour < $1.hour })
        }
        return ranked
            .sorted { $0.total > $1.total }
            .prefix(10)
            .map { (person: $0.handle, data: $0.data) }
    }
    
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
    
    private let hourLabels: [Int:String] = {
        Dictionary(uniqueKeysWithValues:
                    (0...23).map { hour in
            let h12 = hour % 12 == 0 ? 12 : hour % 12
            let suffix = hour < 12 ? "am" : "pm"
            return (hour, "\(h12)\(suffix)")
        }
        )
    }()
    
    
    var body: some View {
        VStack(alignment: .leading) {
            headerView
            chartView          // <-- just one line here!
        }
        .padding()
    }
    
    private var headerView: some View {
        HStack {
            Text("🕒 Top 10 Texters by Hour")
                .font(.title2)
            Spacer()
            Picker("Direction", selection: $messageType) {
                ForEach(MessageType.allCases) { t in
                    Text(t.rawValue).tag(t)
                }
            }
            .pickerStyle(MenuPickerStyle())
        }
        .padding(.bottom, 8)
    }
    
    private var chartView: some View {
        Chart {
            ForEach(chartSeries, id: \.name) { series in
                ForEach(series.data) { pt in
                    LineMark(
                        x: .value("Hour", pt.hour),
                        y: .value("Count", pt.count)
                    )
                    .interpolationMethod(.monotone)
                    .lineStyle(StrokeStyle(lineWidth: 2))
                    .foregroundStyle(by: .value("Person", series.name))
                }
            }
        }
        .chartForegroundStyleScale(
          domain: Array(chartColorMap.keys),
          range: Array(chartColorMap.values)
        )
        .chartLegend(position: .top, alignment: .center, spacing: 8)
        .chartXScale(domain: 0...23)
        .chartXAxis {
            AxisMarks(values: Array(0...23)) { value in
                AxisGridLine(); AxisTick()
                AxisValueLabel() {
                    if let hour = value.as(Int.self) {
                        Text(hourLabels[hour]!)
                    }
                }
            }
        }
        .chartYAxis {
            AxisMarks(position: .leading) {
                AxisGridLine()
                AxisValueLabel()
            }
        }
        .frame(height: 300)
        .padding()
    }
}

#if DEBUG
struct TimeOfDayView_Previews: PreviewProvider {
  static var previews: some View {
    TimeOfDayView()
      .environmentObject(MessagesStore.shared)
      .environmentObject(ContactsViewModel())
  }
}
#endif
