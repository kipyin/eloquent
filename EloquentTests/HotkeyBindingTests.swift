import XCTest

final class HotkeyBindingTests: XCTestCase {
    func testOptionEscapeIsTheDefaultSpeakHotkey() {
        XCTAssertEqual(HotkeyBinding.optionEscape, HotkeyBinding(keyCode: 53, modifiers: .option))
        XCTAssertNil(HotkeyBinding.optionEscape.rejection)
    }

    func testCommandSpaceIsReserved() {
        let binding = HotkeyBinding(keyCode: 49, modifiers: .command)
        XCTAssertEqual(binding.rejection, .reserved)
    }

    func testCommandOptionEscapeIsReserved() {
        let binding = HotkeyBinding(keyCode: 53, modifiers: [.command, .option])
        XCTAssertEqual(binding.rejection, .reserved)
    }

    func testCommandTabIsReserved() {
        let binding = HotkeyBinding(keyCode: 48, modifiers: .command)
        XCTAssertEqual(binding.rejection, .reserved)
    }

    func testShiftOnlyLetterIsIncomplete() {
        let binding = HotkeyBinding(keyCode: 0, modifiers: .shift)
        XCTAssertEqual(binding.rejection, .incomplete)
    }

    func testCommandShiftAIsAccepted() {
        let binding = HotkeyBinding(keyCode: 0, modifiers: [.command, .shift])
        XCTAssertNil(binding.rejection)
    }
}
