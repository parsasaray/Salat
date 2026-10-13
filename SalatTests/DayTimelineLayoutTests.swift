//
//  DayTimelineLayoutTests.swift
//  SalatTests
//

import XCTest

final class DayTimelineLayoutTests: XCTestCase {

    private let width: CGFloat = 295

    /// A typical autumn day, as a position on a line `width` points wide
    private var autumn: [(name: String, x: CGFloat)] {
        [("Dawn", 342), ("Sunrise", 425), ("Noon", 778), ("Afternoon", 972), ("Sunset", 1121), ("Night", 1203)]
            .map { ($0.0, CGFloat($0.1) / 1440 * width) }
    }

    private func halfWidth(of name: String) -> CGFloat {
        (name as NSString).size(withAttributes: [.font: DayTimelineLayout.font]).width / 2
    }

    private func assertNoOverlap(_ labels: [DayTimelineLayout.Label], file: StaticString = #filePath, line: UInt = #line) {
        for (i, a) in labels.enumerated() {
            for b in labels[(i + 1)...] where a.row == b.row {
                let gap = abs(a.center - b.center) - halfWidth(of: a.name) - halfWidth(of: b.name)
                XCTAssertGreaterThan(gap, 0, "\(a.name) and \(b.name) overlap", file: file, line: line)
            }
        }
    }

    func testNeighboringNamesDoNotOverlap() throws {
        let labels = try XCTUnwrap(DayTimelineLayout.labels(for: autumn, width: width))
        XCTAssertEqual(labels.count, 6)
        assertNoOverlap(labels)
    }

    func testNoonAndAfternoonShareNoRow() throws {
        let labels = try XCTUnwrap(DayTimelineLayout.labels(for: autumn, width: width))
        let noon = try XCTUnwrap(labels.first { $0.name == "Noon" })
        let afternoon = try XCTUnwrap(labels.first { $0.name == "Afternoon" })
        // 40 points apart, but Afternoon alone is wider than that
        XCTAssertNotEqual(noon.row, afternoon.row)
    }

    func testNamesStayInsideTheTimeline() throws {
        let edge: [(name: String, x: CGFloat)] = [("Dawn", 2), ("Night", width - 1)]
        let labels = try XCTUnwrap(DayTimelineLayout.labels(for: edge, width: width))
        for label in labels {
            XCTAssertGreaterThanOrEqual(label.center - halfWidth(of: label.name), 0)
            XCTAssertLessThanOrEqual(label.center + halfWidth(of: label.name), width)
        }
    }

    func testGivesUpWhenNamesCannotFit() {
        XCTAssertNil(DayTimelineLayout.labels(for: autumn, width: 130))
    }

    func testSpreadOutNamesStayInTheFirstRow() throws {
        let marks: [(name: String, x: CGFloat)] = [("Dawn", 20), ("Noon", 150), ("Night", 280)]
        let labels = try XCTUnwrap(DayTimelineLayout.labels(for: marks, width: width))
        XCTAssertEqual(labels.map { $0.row }, [0, 0, 0])
    }
}
