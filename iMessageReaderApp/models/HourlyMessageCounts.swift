import Foundation
import SQLite  // SQLite.swift

/// One row of our hourly query
struct MessageHourRecord {
  let person: String            // handle.id (phone/email)
  let hour: Int                 // 0–23
  let direction: MessageDirection
  let count: Int
}

/// Loads & groups the `~/Library/Messages/chat.db` data by
/// (person, hour-of-day, incoming/outgoing) and returns both:
/// 1. an array of records, and
/// 2. a nested lookup [person: [hour: [direction: count]]]
func loadMessageCountsByHour() throws
    -> ([MessageHourRecord], [String: [Int: [MessageDirection: Int]]])
{
    // 1. Resolve path
    let library = FileManager.default
        .urls(for: .libraryDirectory, in: .userDomainMask)
        .first!
    let dbURL = library.appendingPathComponent("Messages/chat.db")
    print("Looking for chat.db at:", dbURL.path)

    // 2. Existence & permissions check
    guard FileManager.default.fileExists(atPath: dbURL.path) else {
        throw NSError(
          domain: "AppData",
          code: 1,
          userInfo: [NSLocalizedDescriptionKey:
                     "chat.db not found at \(dbURL.path)"])
    }

    // 3. Open read-only connection
    let db = try Connection(dbURL.path, readonly: true)

    // 4. Our GROUP-BY query, truncating message.date to hour-of-day (00–23)
    let query = """
    SELECT
      handle.id AS person,
      CAST(strftime(
        '%H',
        (message.date/1000000000) + strftime('%s','2001-01-01'),
        'unixepoch',
        'localtime'
      ) AS INTEGER) AS hour,
      message.is_from_me AS direction,
      COUNT(*) AS count
    FROM message
    LEFT JOIN handle ON handle.ROWID = message.handle_id
    GROUP BY person, hour, message.is_from_me;
    """

    // 5. Execute and build models
    var records: [MessageHourRecord] = []
    var lookup: [String: [Int: [MessageDirection: Int]]] = [:]

    for row in try db.prepare(query) {
      guard
        let person  = row[0] as? String,
        let hourInt = row[1] as? Int64,
        let dirFlag = row[2] as? Int64,
        let cnt     = row[3] as? Int64
      else { continue }

      let direction: MessageDirection = (dirFlag == 1 ? .outgoing : .incoming)
      let record = MessageHourRecord(
        person: person,
        hour: Int(hourInt),
        direction: direction,
        count: Int(cnt)
      )
      records.append(record)

      // populate lookup
      lookup[person, default: [:]][Int(hourInt),
        default: [.incoming: 0, .outgoing: 0]
      ][direction] = Int(cnt)
    }

    return (records, lookup)
}
