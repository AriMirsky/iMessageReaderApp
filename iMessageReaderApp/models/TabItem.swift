import Foundation

struct TabItem: Identifiable, Hashable {
    let id: String
    let title: String
    let systemImage: String
    let kind: Kind

    enum Kind: Hashable {
        case number, readability, wordsearch, timeofday
        case dynamic(dataID: String)
    }
}
