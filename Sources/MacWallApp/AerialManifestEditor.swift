import Foundation

enum AerialManifestEditorError: LocalizedError {
    case invalidRootObject
    case missingAssets
    case missingCategories
    case missingCategory(String)
    case missingSubcategory(String)

    var errorDescription: String? {
        switch self {
        case .invalidRootObject:
            return "The Apple aerial manifest is not a valid JSON dictionary."
        case .missingAssets:
            return "The Apple aerial manifest does not contain an `assets` array."
        case .missingCategories:
            return "The Apple aerial manifest does not contain a `categories` array."
        case let .missingCategory(categoryID):
            return "The Apple aerial manifest does not contain the expected category `\(categoryID)`."
        case let .missingSubcategory(subcategoryID):
            return "The Apple aerial manifest does not contain the expected subcategory `\(subcategoryID)`."
        }
    }
}

struct AerialManifestEditor {
    struct AssetDescriptor {
        let assetID: String
        let title: String
        let videoURL: URL
        let thumbnailURL: URL
    }

    let macCategoryID: String
    let macSubcategoryID: String

    func assetIDs(in data: Data) throws -> Set<String> {
        try Set(assets(in: data).compactMap { asset in
            asset["id"] as? String
        })
    }

    func appendAsset(
        to data: Data,
        descriptor: AssetDescriptor
    ) throws -> Data {
        var rootObject = try rootObject(from: data)
        let categories = try categories(in: rootObject)
        try validateMacCategory(in: categories)

        var assets = try assets(in: rootObject)
        assets.removeAll { asset in
            (asset["id"] as? String) == descriptor.assetID
        }

        let nextPreferredOrder = (assets.compactMap { asset in
            (asset["preferredOrder"] as? NSNumber)?.intValue
        }.max() ?? 0) + 1

        assets.append(
            makeAsset(
                descriptor: descriptor,
                preferredOrder: nextPreferredOrder
            )
        )
        rootObject["assets"] = assets

        return try serializedData(from: rootObject)
    }

    func removeAsset(withID assetID: String, from data: Data) throws -> Data {
        var rootObject = try rootObject(from: data)
        var assets = try assets(in: rootObject)
        let originalCount = assets.count

        assets.removeAll { asset in
            (asset["id"] as? String) == assetID
        }

        guard assets.count != originalCount else {
            return data
        }

        rootObject["assets"] = assets
        return try serializedData(from: rootObject)
    }

    private func makeAsset(
        descriptor: AssetDescriptor,
        preferredOrder: Int
    ) -> [String: Any] {
        let shotIDSeed = descriptor.assetID
            .uppercased()
            .replacingOccurrences(of: "-", with: "_")

        return [
            "accessibilityLabel": descriptor.title,
            "categories": [macCategoryID],
            "id": descriptor.assetID,
            "includeInShuffle": false,
            "localizedNameKey": descriptor.title,
            "pointsOfInterest": [String: String](),
            "preferredOrder": preferredOrder,
            "previewImage": descriptor.thumbnailURL.absoluteString,
            "shotID": "MACWALL_\(shotIDSeed)",
            "showInTopLevel": true,
            "subcategories": [macSubcategoryID],
            "url-4K-SDR-240FPS": descriptor.videoURL.absoluteString,
        ]
    }

    private func validateMacCategory(in categories: [[String: Any]]) throws {
        guard let macCategory = categories.first(where: { category in
            (category["id"] as? String) == macCategoryID
        }) else {
            throw AerialManifestEditorError.missingCategory(macCategoryID)
        }

        guard let subcategories = macCategory["subcategories"] as? [[String: Any]] else {
            throw AerialManifestEditorError.missingSubcategory(macSubcategoryID)
        }

        guard subcategories.contains(where: { subcategory in
            (subcategory["id"] as? String) == macSubcategoryID
        }) else {
            throw AerialManifestEditorError.missingSubcategory(macSubcategoryID)
        }
    }

    private func rootObject(from data: Data) throws -> [String: Any] {
        guard let rootObject = try JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            throw AerialManifestEditorError.invalidRootObject
        }

        return rootObject
    }

    private func assets(in data: Data) throws -> [[String: Any]] {
        let rootObject = try rootObject(from: data)
        return try assets(in: rootObject)
    }

    private func assets(in rootObject: [String: Any]) throws -> [[String: Any]] {
        guard let assets = rootObject["assets"] as? [[String: Any]] else {
            throw AerialManifestEditorError.missingAssets
        }

        return assets
    }

    private func categories(in rootObject: [String: Any]) throws -> [[String: Any]] {
        guard let categories = rootObject["categories"] as? [[String: Any]] else {
            throw AerialManifestEditorError.missingCategories
        }

        return categories
    }

    private func serializedData(from rootObject: [String: Any]) throws -> Data {
        var data = try JSONSerialization.data(withJSONObject: rootObject, options: [.prettyPrinted])
        data.append(0x0A)
        return data
    }
}
