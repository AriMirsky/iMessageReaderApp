import Foundation
import SQLite

// MARK: - Data Structures

/// One row holding readability metrics for a person & direction
struct ReadabilityRecord {
    let person: String
    let direction: MessageDirection
    let words: Int
    let syllables: Int
    let sentences: Int
    let score: Double
}

// MARK: - Syllable Counting

private func countSyllables(in word: String) -> Int {
    let vowels = CharacterSet(charactersIn: "aeiouyAEIOUY")
    var count = 0, lastWasVowel = false
    for scalar in word.unicodeScalars {
        let isV = vowels.contains(scalar)
        if isV && !lastWasVowel { count += 1 }
        lastWasVowel = isV
    }
    return max(1, count)
}

/// Remove any URLs from the string
private func stripURLs(from text: String) -> String {
    guard let detector = try? NSDataDetector(types: NSTextCheckingResult.CheckingType.link.rawValue)
    else { return text }
    let range = NSRange(text.startIndex..<text.endIndex, in: text)
    return detector.stringByReplacingMatches(in: text, options: [], range: range, withTemplate: "")
}

// MARK: - Loader

func loadReadabilityRecords() throws -> [ReadabilityRecord] {
    // Locate Messages database
    let libraryURL = FileManager.default
        .urls(for: .libraryDirectory, in: .userDomainMask)
        .first!
    let dbURL = libraryURL.appendingPathComponent("Messages/chat.db")
    let db = try Connection(dbURL.path, readonly: true)

    // Fetch plain‐text and archived bodies
    let sql = """
    SELECT
      person,
      isFromMe,
      txt,
      attr,
      hasAttachments
    FROM (
      -- 1) Outgoing messages → one row per recipient in the chat
      SELECT
        h.id                           AS person,
        1                              AS isFromMe,           -- outgoing
        m.text                         AS txt,
        m.attributedBody               AS attr,
        m.cache_has_attachments        AS hasAttachments
      FROM message AS m
      JOIN chat_message_join AS cmj
        ON cmj.message_id = m.ROWID
      JOIN chat_handle_join AS chj
        ON chj.chat_id = cmj.chat_id
      JOIN handle AS h
        ON h.ROWID = chj.handle_id
      WHERE m.is_from_me = 1
        AND (
          m.text IS NOT NULL
          OR m.attributedBody IS NOT NULL
          OR m.cache_has_attachments = 1
        )

      UNION ALL

      -- 2) Incoming messages → one row per sender
      SELECT
        h.id                           AS person,
        0                              AS isFromMe,           -- incoming
        m.text                         AS txt,
        m.attributedBody               AS attr,
        m.cache_has_attachments        AS hasAttachments
      FROM message AS m
      JOIN handle AS h
        ON h.ROWID = m.handle_id
      WHERE m.is_from_me = 0
        AND (
          m.text IS NOT NULL
          OR m.attributedBody IS NOT NULL
          OR m.cache_has_attachments = 1
        )
    ) AS combined;
    """

    // Accumulate word/syllable/sentence counts per person & direction
    var stats: [String: [MessageDirection: (words: Int, syllables: Int, sentences: Int)]] = [:]

    for row in try db.prepare(sql) {
        // 1. Identify sender
        guard let person = row[0] as? String,
              let flag   = row[1] as? Int64 else {
            continue
        }
        let direction: MessageDirection = (flag == 1 ? .outgoing : .incoming)

        // 2. Choose message content
        var content: String?
        if let txt = row[2] as? String, !txt.isEmpty {
            content = txt

        } else if let blob = row[3] as? Blob {
            let data = Data(blob.bytes)
            if let attributed = try? NSKeyedUnarchiver
                .unarchivedObject(ofClass: NSAttributedString.self, from: data) {
                content = attributed.string
            }
            else if let legacy = NSUnarchiver.unarchiveObject(with: data) as? NSAttributedString {
                content = legacy.string
            } else {
                content = nil
            }

        } else if let hasAtt = row[4] as? Int64, hasAtt == 1 {
            // attachment‐only; skip scoring
            continue

        } else {
            // no usable content
            continue
        }

        guard let text = content, !text.isEmpty else {
            continue  // skip empty text
        }

        // strip URLs
        let cleaned = stripURLs(from: text)

        // 3. Count sentences
        let sentenceCount = cleaned
            .components(separatedBy: CharacterSet(charactersIn: ".!?\n"))
            .filter { !$0.trimmingCharacters(in: .whitespaces).isEmpty }
            .count

        // 4. Count words and syllables
        let wordsArr = cleaned
            .components(separatedBy: .whitespacesAndNewlines)
            .filter { !$0.isEmpty }
        let wordCount = wordsArr.count
        let syllableCount = wordsArr.reduce(0) { $0 + countSyllables(in: $1) }

        // 5. Accumulate
        var entry = stats[person]?[direction] ?? (words: 0, syllables: 0, sentences: 0)
        entry.words     += wordCount
        entry.syllables += syllableCount
        entry.sentences += sentenceCount
        stats[person] = (stats[person] ?? [:]).merging([direction: entry]) { $1 }
    }

    // 6. Build final records
    var records: [ReadabilityRecord] = []
    for (person, dirStats) in stats {
        for (direction, tallies) in dirStats {
            let w = tallies.words, s = tallies.syllables, t = tallies.sentences
            guard w > 0, t > 0 else { continue }
            let score = 0.39 * (Double(w) / Double(t))
                      + 11.8 * (Double(s) / Double(w))
                      - 15.59
            records.append(ReadabilityRecord(
                person:    person,
                direction: direction,
                words:     w,
                syllables: s,
                sentences: t,
                score:     score
            ))
        }
    }

    return records
}

// MARK: - ViewModel

final class ReadabilityViewModel: ObservableObject {
    struct Entry: Identifiable {
        let id: UUID = .init()
        let person: String
        let score: Double
        let words: Int
        let sentences: Int
        let syllables: Int
    }

    @Published private(set) var top5Incoming: [Entry] = []
    @Published private(set) var top5Outgoing: [Entry] = []
    @Published private(set) var bottom5Incoming: [Entry] = []
    @Published private(set) var bottom5Outgoing: [Entry] = []
    @Published private(set) var popular10Incoming: [Entry] = []
    @Published private(set) var popular10Outgoing: [Entry] = []
    
    // NEW: lookup by person → (direction → entry)
    @Published private(set) var entryLookup: [String: [MessageDirection: Entry]] = [:]

    init() {
        computeRankings()
    }

    private func computeRankings() {
        do {
            let recs = try loadReadabilityRecords()
            
            // ← NEW: build the lookup
            var lookup: [String: [MessageDirection: Entry]] = [:]
            for rec in recs {
                let e = Entry(
                    person:    rec.person,
                    score:     rec.score,
                    words:     rec.words,
                    sentences: rec.sentences,
                    syllables: rec.syllables
                )
                lookup[rec.person, default: [:]][rec.direction] = e
            }
            entryLookup = lookup

            let inc = recs
                .filter { $0.direction == .incoming }
                .filter { $0.words >= 50}
                .map { rec in Entry(
                    person:    rec.person,
                    score:     rec.score,
                    words:     rec.words,
                    sentences: rec.sentences,
                    syllables: rec.syllables
                )}
                .sorted { $0.score > $1.score }
            top5Incoming = Array(inc.prefix(5))

            let out = recs
                .filter { $0.direction == .outgoing }
                .filter { $0.words >= 50}
                .map { rec in Entry(
                    person:    rec.person,
                    score:     rec.score,
                    words:     rec.words,
                    sentences: rec.sentences,
                    syllables: rec.syllables
                )}
                .sorted { $0.score > $1.score }
            top5Outgoing = Array(out.prefix(5))
            
            let inc2 = recs
                .filter { $0.direction == .incoming }
                .filter { $0.words >= 50}
                .map { rec in Entry(
                    person:    rec.person,
                    score:     rec.score,
                    words:     rec.words,
                    sentences: rec.sentences,
                    syllables: rec.syllables
                )}
                .sorted { $0.score < $1.score }
            bottom5Incoming = Array(inc2.prefix(5))

            let out2 = recs
                .filter { $0.direction == .outgoing }
                .filter { $0.words >= 50}
                .map { rec in Entry(
                    person:    rec.person,
                    score:     rec.score,
                    words:     rec.words,
                    sentences: rec.sentences,
                    syllables: rec.syllables
                )}
                .sorted { $0.score < $1.score }
            bottom5Outgoing = Array(out2.prefix(5))
            
            let inc3 = recs
                .filter { $0.direction == .incoming }
                .map { rec in Entry(
                    person:    rec.person,
                    score:     rec.score,
                    words:     rec.words,
                    sentences: rec.sentences,
                    syllables: rec.syllables
                )}
                .sorted { $0.words > $1.words }
            popular10Incoming = Array(inc3.prefix(10))

            let out3 = recs
                .filter { $0.direction == .outgoing }
                .map { rec in Entry(
                    person:    rec.person,
                    score:     rec.score,
                    words:     rec.words,
                    sentences: rec.sentences,
                    syllables: rec.syllables
                )}
                .sorted { $0.words > $1.words }
            popular10Outgoing = Array(out3.prefix(10))

        } catch {
            print("❌ Readability load failed:", error)
        }
    }
}
