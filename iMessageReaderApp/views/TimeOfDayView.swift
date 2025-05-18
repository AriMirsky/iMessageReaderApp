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

  var body: some View {
    VStack(alignment: .leading) {
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

      Chart {
        ForEach(seriesList, id: \.person) { series in
          ForEach(series.data) { pt in
            LineMark(
              x: .value("Hour", pt.hour),
              y: .value("Count", pt.count)
            )
            .interpolationMethod(.monotone)
            .lineStyle(StrokeStyle(lineWidth: 2))
            .foregroundStyle(
              by: .value("Person",
                         contactsVM.displayName(for: series.person))
            )
          }
        }
      }
      .chartXScale(domain: 0...23)
      .chartXAxis {
        AxisMarks(values: Array(0...23)) { value in
          // draw the grid line and tick
          AxisGridLine()
          AxisTick()
          // format the label as 12-hour with am/pm
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
          AxisGridLine()
          AxisValueLabel()
        }
      }
      .frame(height: 300)
      .padding()
    }
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
