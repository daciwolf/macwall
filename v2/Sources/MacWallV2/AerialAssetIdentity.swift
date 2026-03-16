import Foundation

enum AerialAssetIdentity {
    static func sanitizedAssetID(from text: String) -> String {
        let loweredText = text
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .lowercased()

        var result = ""
        var previousCharacterWasSeparator = false

        for character in loweredText {
            if character.macWallV2IsAlphaNumeric {
                result.append(character)
                previousCharacterWasSeparator = false
                continue
            }

            if character == "-" || character == "_" || character.macWallV2IsWhitespace {
                guard !result.isEmpty, !previousCharacterWasSeparator else {
                    continue
                }

                result.append("-")
                previousCharacterWasSeparator = true
                continue
            }

            guard !result.isEmpty, !previousCharacterWasSeparator else {
                continue
            }

            result.append("-")
            previousCharacterWasSeparator = true
        }

        while let lastCharacter = result.last, lastCharacter == "-" || lastCharacter == "_" {
            result.removeLast()
        }

        return result.isEmpty ? "custom-aerial" : result
    }

    static func uniqueAssetID(from preferredText: String, existingIDs: Set<String>) -> String {
        let baseID = sanitizedAssetID(from: preferredText)
        guard existingIDs.contains(baseID) else {
            return baseID
        }

        var counter = 2
        while existingIDs.contains("\(baseID)-\(counter)") {
            counter += 1
        }

        return "\(baseID)-\(counter)"
    }

    static func sanitizedFileName(baseName: String, fileExtension: String) -> String {
        let safeBaseName = sanitizedAssetID(from: baseName)
        return "\(safeBaseName).\(fileExtension)"
    }
}

private extension Character {
    var macWallV2IsAlphaNumeric: Bool {
        unicodeScalars.allSatisfy(CharacterSet.alphanumerics.contains)
    }

    var macWallV2IsWhitespace: Bool {
        unicodeScalars.allSatisfy(CharacterSet.whitespacesAndNewlines.contains)
    }
}
