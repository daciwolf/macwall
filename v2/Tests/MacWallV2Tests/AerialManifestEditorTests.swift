import Foundation
import Testing
@testable import MacWallV2

@Test
func appendAssetPreservesTopLevelMetadataAndTargetsMacCategory() throws {
    let editor = AerialManifestEditor(
        macCategoryID: "8048287A-39E6-4093-87EC-B0DCE7CB4A29",
        macSubcategoryID: "989909D1-AEFC-4BE5-9249-ABFBA5CABED0"
    )
    let originalData = Data(sampleManifest.utf8)

    let updatedData = try editor.appendAsset(
        to: originalData,
        descriptor: .init(
            assetID: "custom-mac-wallpaper",
            title: "Custom Mac Wallpaper",
            videoURL: URL(fileURLWithPath: "/tmp/custom.mov"),
            thumbnailURL: URL(fileURLWithPath: "/tmp/custom.png")
        )
    )

    let rootObject = try #require(try JSONSerialization.jsonObject(with: updatedData) as? [String: Any])
    #expect(rootObject["initialAssetCount"] as? Int == 4)
    #expect(rootObject["localizationVersion"] as? String == "22L-1")
    #expect(rootObject["version"] as? Int == 1)

    let assets = try #require(rootObject["assets"] as? [[String: Any]])
    let customAsset = try #require(assets.first(where: { asset in
        (asset["id"] as? String) == "custom-mac-wallpaper"
    }))

    #expect(customAsset["accessibilityLabel"] as? String == "Custom Mac Wallpaper")
    #expect(customAsset["localizedNameKey"] as? String == "Custom Mac Wallpaper")
    #expect(customAsset["categories"] as? [String] == ["8048287A-39E6-4093-87EC-B0DCE7CB4A29"])
    #expect(customAsset["subcategories"] as? [String] == ["989909D1-AEFC-4BE5-9249-ABFBA5CABED0"])
    #expect(customAsset["previewImage"] as? String == "file:///tmp/custom.png")
    #expect(customAsset["url-4K-SDR-240FPS"] as? String == "file:///tmp/custom.mov")
}

@Test
func removeAssetDeletesOnlyTheRequestedAsset() throws {
    let editor = AerialManifestEditor(
        macCategoryID: "8048287A-39E6-4093-87EC-B0DCE7CB4A29",
        macSubcategoryID: "989909D1-AEFC-4BE5-9249-ABFBA5CABED0"
    )
    let originalData = Data(sampleManifest.utf8)

    let updatedData = try editor.removeAsset(withID: "94383DC9-59D3-43EC-9E8E-A783DA633E06", from: originalData)
    let rootObject = try #require(try JSONSerialization.jsonObject(with: updatedData) as? [String: Any])
    let assets = try #require(rootObject["assets"] as? [[String: Any]])

    #expect(assets.contains(where: { asset in
        (asset["id"] as? String) == "94383DC9-59D3-43EC-9E8E-A783DA633E06"
    }) == false)
    #expect(assets.contains(where: { asset in
        (asset["id"] as? String) == "EE01F02D-1413-436C-AB05-410F224A5B7B"
    }))
    #expect(rootObject["localizationVersion"] as? String == "22L-1")
}

private let sampleManifest = """
{
  "assets" : [
    {
      "accessibilityLabel" : "Landscapes",
      "categories" : [
        "A33A55D9-EDEA-4596-A850-6C10B54FBBB5"
      ],
      "id" : "EE01F02D-1413-436C-AB05-410F224A5B7B",
      "includeInShuffle" : true,
      "localizedNameKey" : "LANDSCAPE_NAME",
      "pointsOfInterest" : {
      },
      "preferredOrder" : 1,
      "previewImage" : "https://example.com/landscape.png",
      "shotID" : "LANDSCAPE",
      "showInTopLevel" : true,
      "subcategories" : [
        "0DC99DD8-3386-4D1E-8878-C43E97EB710A"
      ],
      "url-4K-SDR-240FPS" : "https://example.com/landscape.mov"
    },
    {
      "accessibilityLabel" : "Mac Blue",
      "categories" : [
        "8048287A-39E6-4093-87EC-B0DCE7CB4A29"
      ],
      "id" : "94383DC9-59D3-43EC-9E8E-A783DA633E06",
      "includeInShuffle" : false,
      "localizedNameKey" : "MAC_WP_BLU_NAME",
      "pointsOfInterest" : {
      },
      "preferredOrder" : 81,
      "previewImage" : "https://example.com/mac-blue.png",
      "shotID" : "MAC_WP_BLU",
      "showInTopLevel" : true,
      "subcategories" : [
        "989909D1-AEFC-4BE5-9249-ABFBA5CABED0"
      ],
      "url-4K-SDR-240FPS" : "https://example.com/mac-blue.mov"
    }
  ],
  "categories" : [
    {
      "id" : "8048287A-39E6-4093-87EC-B0DCE7CB4A29",
      "localizedDescriptionKey" : "AerialCategoryMacDescription",
      "localizedNameKey" : "AerialCategoryMac",
      "preferredOrder" : 4,
      "previewImage" : "https://example.com/mac-category.png",
      "representativeAssetID" : "94383DC9-59D3-43EC-9E8E-A783DA633E06",
      "subcategories" : [
        {
          "id" : "989909D1-AEFC-4BE5-9249-ABFBA5CABED0",
          "localizedDescriptionKey" : "AerialSubcategoryDescriptionMac",
          "localizedNameKey" : "AerialSubcategoryDescriptionMac",
          "preferredOrder" : 0,
          "previewImage" : "https://example.com/mac-category.png",
          "representativeAssetID" : "94383DC9-59D3-43EC-9E8E-A783DA633E06"
        }
      ]
    }
  ],
  "initialAssetCount" : 4,
  "localizationVersion" : "22L-1",
  "version" : 1
}
"""
