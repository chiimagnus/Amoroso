import Foundation
@testable import HappyPianistAVP
import Testing

@Test
func logicalInstrumentModelNormalizesMemberOrderAndSupportsEquality() {
    let evidence = MusicXMLLogicalInstrumentEvidence(kind: .splitKeyboardPartNames, partIDs: ["P2", "P1"])
    let lhs = MusicXMLLogicalInstrument(
        id: "piano:P1+P2",
        memberPartIDs: ["P2", "P1", "P1"],
        classification: .piano,
        evidence: [evidence]
    )
    let rhs = MusicXMLLogicalInstrument(
        id: "piano:P1+P2",
        memberPartIDs: ["P1", "P2"],
        classification: .piano,
        evidence: [evidence]
    )
    #expect(lhs == rhs)
    #expect(lhs.memberPartIDs == ["P1", "P2"])
}

@Test
func normalizerGroupsExplicitSplitPianoWithoutRewritingSourceParts() throws {
    let xml = """
    <score-partwise version="4.0">
      <part-list>
        <score-part id="RH"><part-name>Piano RH</part-name></score-part>
        <score-part id="LH"><part-name>Piano LH</part-name></score-part>
      </part-list>
      <part id="RH"><measure number="1"><attributes><divisions>1</divisions><clef><sign>G</sign><line>2</line></clef></attributes>
        <note><pitch><step>C</step><octave>5</octave></pitch><duration>1</duration></note>
      </measure></part>
      <part id="LH"><measure number="1"><attributes><divisions>1</divisions><clef><sign>F</sign><line>4</line></clef></attributes>
        <direction><direction-type><dynamics><p/></dynamics></direction-type></direction>
        <note><pitch><step>C</step><octave>3</octave></pitch><duration>1</duration></note>
      </measure></part>
    </score-partwise>
    """
    let raw = try MusicXMLParser().parse(data: Data(xml.utf8))
    let normalized = MusicXMLPianoGrandStaffNormalizer().normalize(score: raw)
    let piano = try #require(normalized.logicalInstruments.only)
    let filtered = normalized.filtering(toLogicalInstrument: piano)

    #expect(piano.classification == .piano)
    #expect(piano.memberPartIDs == ["LH", "RH"])
    #expect(Set(filtered.notes.map(\.partID)) == ["LH", "RH"])
    #expect(filtered.dynamicEvents.contains { $0.scope.partID == "LH" })
    #expect(Set(filtered.measures.map(\.partID)) == ["LH", "RH"])
}

@Test
func normalizerDoesNotMergeIndependentTrebleAndBassInstruments() throws {
    let xml = """
    <score-partwise version="4.0">
      <part-list>
        <score-part id="P1"><part-name>Flute</part-name></score-part>
        <score-part id="P2"><part-name>Cello</part-name></score-part>
      </part-list>
      <part id="P1"><measure number="1"><attributes><divisions>1</divisions><clef><sign>G</sign><line>2</line></clef></attributes>
        <note><pitch><step>C</step><octave>5</octave></pitch><duration>1</duration></note>
      </measure></part>
      <part id="P2"><measure number="1"><attributes><divisions>1</divisions><clef><sign>F</sign><line>4</line></clef></attributes>
        <note><pitch><step>C</step><octave>3</octave></pitch><duration>1</duration></note>
      </measure></part>
    </score-partwise>
    """
    let normalized = MusicXMLPianoGrandStaffNormalizer().normalize(
        score: try MusicXMLParser().parse(data: Data(xml.utf8))
    )
    #expect(normalized.logicalInstruments.count == 2)
    #expect(normalized.logicalInstruments.allSatisfy { $0.memberPartIDs.count == 1 })
    #expect(normalized.logicalInstruments.allSatisfy { $0.classification == .other })
}

private extension Collection {
    var only: Element? { count == 1 ? first : nil }
}
