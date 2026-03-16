import Testing
@testable import MacWallV2

@Test
func sanitizedAssetIDNormalizesWhitespaceAndSymbols() {
    #expect(AerialAssetIdentity.sanitizedAssetID(from: "  Test MOV 4K!  ") == "test-mov-4k")
}

@Test
func uniqueAssetIDAddsNumericSuffixWhenNeeded() {
    let existingIDs: Set<String> = ["test", "test-2"]
    #expect(AerialAssetIdentity.uniqueAssetID(from: "Test", existingIDs: existingIDs) == "test-3")
}

@Test
func sanitizedFileNameFallsBackWhenInputIsBlank() {
    #expect(AerialAssetIdentity.sanitizedFileName(baseName: "   ", fileExtension: "mov") == "custom-aerial.mov")
}
