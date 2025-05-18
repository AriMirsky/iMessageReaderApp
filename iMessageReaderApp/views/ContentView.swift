import SwiftUI

struct ContentView: View {
    @EnvironmentObject var store: MessagesStore
    @EnvironmentObject var contactsVM: ContactsViewModel
    @State private var selection: TabItem?

    // MARK: Static tabs
    private let staticTabs: [TabItem] = [
        .init(id: "number",
              title: "Number",
              systemImage: "house",
              kind: .number),
        .init(id: "readability",
              title: "Readability",
              systemImage: "house",
              kind: .readability),
        .init(id: "wordsearch",
              title: "Word Search",
              systemImage: "house",
              kind: .wordsearch),
        .init(id: "timeofday",
              title: "Time of Day",
             systemImage: "house",
              kind: .timeofday),
    ]

    var body: some View {
        NavigationView {
            List(selection: $selection) {
                Section("Overall") {
                    ForEach(staticTabs) { tab in
                        Label(tab.title, systemImage: tab.systemImage)
                            .tag(tab)
                    }
                }

                Section("People") {
                    // Sort handles by total message count descending
                    let sortedPeople = store.lookup
                        .map { person, days in
                            let total = days.values
                                .flatMap { $0.values }
                                .reduce(0, +)
                            return (person, total)
                        }
                        .sorted { $0.1 > $1.1 }
                        .map { $0.0 }

                    ForEach(sortedPeople, id: \.self) { person in
                        let tab = TabItem(
                            id: person,
                            title: contactsVM.displayName(for: person),
                            systemImage: "person",
                            kind: .dynamic(dataID: person)
                        )
                        Label(tab.title, systemImage: tab.systemImage)
                            .tag(tab)
                    }
                }
            }
            .listStyle(SidebarListStyle())
            .frame(minWidth: 150)

            DetailArea(selection: selection)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
    }
}

private struct DetailArea: View {
    let selection: TabItem?

    var body: some View {
        switch selection?.kind {
        case .number:
            NumberView()
        case .readability:
            ReadabilityView()
        case .wordsearch:
            WordSearchView()
        case .timeofday:
            TimeOfDayView()
        case .dynamic(let dataID):
            DynamicDetailView(itemID: dataID)
        default:
            Text("""
            To use the app, follow the instructions at https://support.apple.com/guide/mac-help/open-a-mac-app-from-an-unknown-developer-mh40616/mac.
            
            Then, also in Privacy & Security, go to Full Disk Access and allow iMessageReaderApp. You may need to restart the app.
            """).italic()
        }
    }
}

#Preview {
    ContentView()
        .environmentObject(MessagesStore.shared)
}
