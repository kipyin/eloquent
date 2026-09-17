import XCTest
@testable import Eloquent

final class ParagraphSplitterTests: XCTestCase {
    func testEmptyAndWhitespaceYieldNoParagraphs() {
        XCTAssertEqual(ParagraphSplitter.split("", mode: .blankLinesThenNewlines), [])
        XCTAssertEqual(ParagraphSplitter.split("  \n\t\n  ", mode: .everyNewline), [])
        XCTAssertEqual(ParagraphSplitter.split("\r\n", mode: .sentences), [])
    }

    func testBlankLinesOnlyKeepsSingleNewlines() {
        XCTAssertEqual(
            ParagraphSplitter.split("Hello\nWorld", mode: .blankLinesOnly),
            ["Hello\nWorld"]
        )
        XCTAssertEqual(
            ParagraphSplitter.split("Hello\n\nWorld", mode: .blankLinesOnly),
            ["Hello", "World"]
        )
        XCTAssertEqual(
            ParagraphSplitter.split("Hello\n  \nWorld", mode: .blankLinesOnly),
            ["Hello", "World"]
        )
    }

    func testEveryNewlineSplitsOnEachLine() {
        XCTAssertEqual(
            ParagraphSplitter.split("Hello\nWorld", mode: .everyNewline),
            ["Hello", "World"]
        )
        XCTAssertEqual(
            ParagraphSplitter.split("Hello\n\nWorld", mode: .everyNewline),
            ["Hello", "World"]
        )
    }

    func testBlankLinesThenNewlinesUsesBlankLinesWhenPresent() {
        XCTAssertEqual(
            ParagraphSplitter.split("Hello\n\nWorld", mode: .blankLinesThenNewlines),
            ["Hello", "World"]
        )
        XCTAssertEqual(
            ParagraphSplitter.split("Hello\nWorld", mode: .blankLinesThenNewlines),
            ["Hello", "World"]
        )
        XCTAssertEqual(
            ParagraphSplitter.split("Hello", mode: .blankLinesThenNewlines),
            ["Hello"]
        )
    }

    func testSentencesSplitOnWesternAndCJKTerminators() {
        XCTAssertEqual(
            ParagraphSplitter.split("Hello. World!", mode: .sentences),
            ["Hello.", "World!"]
        )
        XCTAssertEqual(
            ParagraphSplitter.split("你好。世界！", mode: .sentences),
            ["你好。", "世界！"]
        )
        XCTAssertEqual(
            ParagraphSplitter.split("He said \"Hi.\" Next.", mode: .sentences),
            ["He said \"Hi.\"", "Next."]
        )
        XCTAssertEqual(
            ParagraphSplitter.split("No terminator", mode: .sentences),
            ["No terminator"]
        )
    }

    func testCarriageReturnsNormalizeBeforeSplit() {
        XCTAssertEqual(
            ParagraphSplitter.split("A\r\n\r\nB", mode: .blankLinesOnly),
            ["A", "B"]
        )
        XCTAssertEqual(
            ParagraphSplitter.split("A\rB", mode: .everyNewline),
            ["A", "B"]
        )
    }
}
