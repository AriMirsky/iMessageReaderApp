//
//  MessagesStore.swift
//  iMessageReaderApp
//
//  Created by Ari Mirsky on 5/16/25.
//
import Foundation


final class MessagesStore: ObservableObject {
  static let shared = MessagesStore()

  @Published private(set) var records: [MessageCountRecord] = []
  @Published private(set) var lookup: [String: [Date: [MessageDirection: Int]]] = [:]
    @Published private(set) var hourlyLookup: [String:[Int:[MessageDirection:Int]]] = [:]
    @Published var readabilityIncoming: [(person: String, score: Double)] = []
    @Published var readabilityOutgoing: [(person: String, score: Double)] = []


  func set(records: [MessageCountRecord],
           lookup: [String: [Date: [MessageDirection: Int]]]) {
    self.records = records
    self.lookup  = lookup
  }
    
    func setHourly(records: [MessageHourRecord],
                   lookup: [String:[Int:[MessageDirection:Int]]]) {
      self.hourlyLookup = lookup
    }
    
    func setReadability(incoming: [(person: String, score: Double)],
                        outgoing: [(person: String, score: Double)]) {
        self.readabilityIncoming = incoming
        self.readabilityOutgoing = outgoing
    }

}
