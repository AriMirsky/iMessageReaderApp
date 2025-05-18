import SwiftUI

@main
struct iMessageReaderAppApp: App {
    // 1. Create the store as a StateObject
    @StateObject private var store = MessagesStore.shared
    @StateObject private var contactsVM = ContactsViewModel()
    @StateObject private var readabilityVM = ReadabilityViewModel()

    init() {
        do {
            let (allRecords, lookupTable) = try loadMessageCounts()
            store.set(records: allRecords, lookup: lookupTable)
        } catch {
            print("❌ Failed to load messages:", error)
        }
        do {
            let (hourRecords, hourLookup) = try loadMessageCountsByHour()
            store.setHourly(records: hourRecords, lookup: hourLookup)
        } catch {
            print("❌ Failed to load messages:", error)
        }
    }

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(store)  // Inject the store into the SwiftUI environment
                .environmentObject(contactsVM)
                .environmentObject(readabilityVM)
                .frame(minWidth: 600, minHeight: 400)
        }
    }
}
