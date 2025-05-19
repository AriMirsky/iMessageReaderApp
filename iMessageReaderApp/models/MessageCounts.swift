import Foundation
import SQLite  // SQLite.swift

/// Direction of a message
enum MessageDirection: String {
  case incoming, outgoing
}

/// One row of our grouped query
struct MessageCountRecord {
  let person: String            // handle.id (phone/email)
  let day: Date                 // truncated to calendar day
  let direction: MessageDirection
  let count: Int
}

/// Loads & groups the `~/Library/Messages/chat.db` data by
/// (person, day, incoming/outgoing) and returns both:
/// 1. an array of records, and
/// 2. a nested lookup [person: [day: [direction: count]]]
func loadMessageCounts() throws
    -> ([MessageCountRecord], [String: [Date: [MessageDirection: Int]]])
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

    // 2. Open read-only connection
    let db = try Connection(dbURL.path, readonly: true)

    // 3. Our GROUP-BY query
    let query = """
    SELECT 
      person,
      day,
      direction,
      COUNT(*) AS count
    FROM (
        -- Subquery 1: Outgoing messages (is_from_me = 1), count per recipient in chats
        SELECT 
          h.id AS person,
          DATE((m.date/1000000000) + strftime('%s','2001-01-01'), 'unixepoch') AS day,
          1 AS direction        -- message.is_from_me = 1 for outgoing
        FROM message AS m
        JOIN chat_message_join AS cmj 
          ON cmj.message_id = m.ROWID
        JOIN chat_handle_join AS chj 
          ON chj.chat_id = cmj.chat_id
        JOIN handle AS h 
          ON h.ROWID = chj.handle_id
        WHERE m.is_from_me = 1
          -- Exclude the sender's own handle if present (typically the sender isn't in chat_handle_join)
        
        UNION ALL
        
        -- Subquery 2: Incoming messages (is_from_me = 0), count per sender
        SELECT 
          h.id AS person,
          DATE((m.date/1000000000) + strftime('%s','2001-01-01'), 'unixepoch') AS day,
          0 AS direction        -- message.is_from_me = 0 for incoming
        FROM message AS m
        JOIN handle AS h 
          ON h.ROWID = m.handle_id
        WHERE m.is_from_me = 0
    ) AS combined
    GROUP BY person, day, direction;
    """

    // 4. Execute and build models
    var records: [MessageCountRecord] = []
    var lookup: [String: [Date: [MessageDirection: Int]]] = [:]

    let df = DateFormatter()
    df.dateFormat = "yyyy-MM-dd"

    for row in try db.prepare(query) {
      guard
        let person    = row[0] as? String,
        let dayString = row[1] as? String,
        let dirFlag   = row[2] as? Int64,
        let cnt       = row[3] as? Int64,
        let date      = df.date(from: dayString)
      else { continue }

      let direction: MessageDirection = (dirFlag == 1 ? .outgoing : .incoming)
      let record = MessageCountRecord(person: person,
                                      day: date,
                                      direction: direction,
                                      count: Int(cnt))
      records.append(record)

      // populate lookup
      lookup[person, default: [:]][date, default: [.incoming: 0, .outgoing: 0]][direction] = Int(cnt)
    }

    return (records, lookup)
}
