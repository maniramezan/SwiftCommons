import Foundation

/// Splits transcripts into comparable words for ``TranscriptAlignment``.
enum TranscriptNormalizer {
    /// Splits `text` into words, keeping each word's original spelling.
    ///
    /// Whitespace, hyphens, dashes, and slashes separate words. Punctuation at the edges of a word
    /// is dropped; apostrophes inside a word (`don't`, `o'clock`) are kept and straightened.
    static func words(in text: String) -> [String] {
        let separators = CharacterSet.whitespacesAndNewlines
            .union(CharacterSet(charactersIn: "-‐‑‒–—/"))
        return text.components(separatedBy: separators).compactMap { raw in
            let straightened = raw.replacing("’", with: "'").replacing("‘", with: "'")
            let trimmed = straightened.trimmingCharacters(in: edgePunctuation)
            return trimmed.isEmpty ? nil : trimmed
        }
    }

    /// The case-folded, diacritic-preserving comparison key for a word.
    static func key(for word: String, locale: Locale) -> String {
        word.replacing("’", with: "'").lowercased(with: locale)
    }

    private static let edgePunctuation = CharacterSet.punctuationCharacters
        .union(.symbols)
        .union(CharacterSet(charactersIn: "'"))
}

/// Word-level minimum edit distance with a deterministic backtrace.
enum EditDistance {
    /// One step turning the reference sequence into the heard sequence.
    enum Operation: Equatable {
        /// Reference index `r` equals heard index `h`.
        case keep(Int, Int)
        /// Reference index `r` was replaced by heard index `h`.
        case substitute(Int, Int)
        /// Reference index `r` is missing from the heard sequence.
        case delete(Int)
        /// Heard index `h` has no counterpart in the reference.
        case insert(Int)
    }

    /// The cheapest operations, in order, that turn `reference` into `heard`.
    ///
    /// Substitutions, deletions, and insertions each cost one. On ties the backtrace prefers a
    /// keep or substitution, then a deletion, then an insertion, so results are stable.
    static func operations(from reference: [String], to heard: [String]) -> [Operation] {
        let rows = reference.count
        let columns = heard.count
        var cost = Array(repeating: Array(repeating: 0, count: columns + 1), count: rows + 1)
        for r in 0...rows { cost[r][0] = r }
        for h in 0...columns { cost[0][h] = h }
        if rows > 0 && columns > 0 {
            for r in 1...rows {
                for h in 1...columns {
                    let diagonal = cost[r - 1][h - 1] + (reference[r - 1] == heard[h - 1] ? 0 : 1)
                    cost[r][h] = min(diagonal, cost[r - 1][h] + 1, cost[r][h - 1] + 1)
                }
            }
        }

        var result: [Operation] = []
        var r = rows
        var h = columns
        while r > 0 || h > 0 {
            if r > 0 && h > 0 {
                let same = reference[r - 1] == heard[h - 1]
                if cost[r][h] == cost[r - 1][h - 1] + (same ? 0 : 1) {
                    result.append(same ? .keep(r - 1, h - 1) : .substitute(r - 1, h - 1))
                    r -= 1
                    h -= 1
                    continue
                }
            }
            if r > 0 && cost[r][h] == cost[r - 1][h] + 1 {
                result.append(.delete(r - 1))
                r -= 1
            } else {
                result.append(.insert(h - 1))
                h -= 1
            }
        }
        return result.reversed()
    }
}
