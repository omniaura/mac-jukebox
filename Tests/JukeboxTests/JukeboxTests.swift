import XCTest
@testable import Jukebox

final class LibraryTests: XCTestCase {
    var dir: URL!

    override func setUpWithError() throws {
        dir = FileManager.default.temporaryDirectory.appendingPathComponent("jukebox-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: dir.appendingPathComponent("sub"), withIntermediateDirectories: true)
    }

    override func tearDown() { try? FileManager.default.removeItem(at: dir) }

    @discardableResult
    func touch(_ name: String, _ bytes: String = "x") throws -> String {
        let url = dir.appendingPathComponent(name)
        try bytes.write(to: url, atomically: true, encoding: .utf8)
        return url.path
    }

    func testRecursesAndKeepsOnlyAudioInNaturalOrder() throws {
        try touch("b.wav"); try touch("a10.mp3"); try touch("a2.mp3"); try touch("cover.png"); try touch("sub/z.m4a")
        let names = Library.collect([dir.path]).map { URL(fileURLWithPath: $0).lastPathComponent }
        XCTAssertEqual(names, ["a2.mp3", "a10.mp3", "b.wav", "z.m4a"])
    }

    func testSkipsAppleDoubleFiles() throws {
        try touch("._ghost.wav"); try touch("real.wav")
        XCTAssertEqual(Library.collect([dir.path]).count, 1)
    }

    func testDropsSameNameSameSizeCopies() throws {
        try touch("song.wav", "abc"); try touch("sub/song.wav", "abc"); try touch("sub/other.wav", "abc")
        XCTAssertEqual(Library.collect([dir.path]).count, 2)
        XCTAssertEqual(Library.collect([dir.path], dedupe: false).count, 3)
    }

    func testSameNameDifferentSizeIsKept() throws {
        try touch("song.wav", "abc"); try touch("sub/song.wav", "abcdef")
        XCTAssertEqual(Library.collect([dir.path]).count, 2)
    }

    func testM3URelativeAndAbsoluteEntries() throws {
        let a = try touch("sub/a.wav"); try touch("sub/b.mp3")
        try "#EXTM3U\n#EXTINF:1,x\nb.mp3\n\(a)\nmissing.wav\n".write(to: dir.appendingPathComponent("sub/l.m3u"), atomically: true, encoding: .utf8)
        let names = Library.collect([dir.appendingPathComponent("sub/l.m3u").path]).map { URL(fileURLWithPath: $0).lastPathComponent }
        XCTAssertEqual(names, ["b.mp3", "a.wav"])
    }

    func testMissingInputIsIgnored() {
        XCTAssertEqual(Library.collect(["/definitely/not/here"]), [])
    }
}

final class ProtocolTests: XCTestCase {
    func testRequestRoundTrip() throws {
        let req = Request(cmd: "cue", args: ["/a b/c.wav"], opts: ["shuffle": "1"])
        let back = try JSONDecoder().decode(Request.self, from: JSONEncoder().encode(req))
        XCTAssertEqual(back.args, req.args)
        XCTAssertEqual(back.opts, req.opts)
    }

    func testSocketPathFitsInSockaddrUn() {
        XCTAssertLessThan(Paths.socket.utf8.count, 104)
    }

    func testParseTime() {
        let h = Handler(engine: Engine())
        XCTAssertEqual(h.parseTime("90"), 90)
        XCTAssertEqual(h.parseTime("1:30"), 90)
        XCTAssertEqual(h.parseTime("1:01:01"), 3661)
        XCTAssertNil(h.parseTime("abc"))
    }
}
