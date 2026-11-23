import Foundation
import CryptoKit

@main struct UpdateSignatureTests {
    static func main() throws {
        let root = URL(fileURLWithPath: FileManager.default.currentDirectoryPath)
        let temporary = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: temporary, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: temporary) }
        let key = Curve25519.Signing.PrivateKey()
        let privateInput = key.rawRepresentation.base64EncodedData()
        func signTool(_ arguments: [String]) throws -> (Int32, Data) {
            let process = Process()
            process.executableURL = root.appendingPathComponent("Vendor/Sparkle/bin/sign_update")
            process.arguments = ["--ed-key-file", "-"] + arguments
            let input = Pipe(), output = Pipe()
            process.standardInput = input; process.standardOutput = output; process.standardError = FileHandle.nullDevice
            try process.run()
            input.fileHandleForWriting.write(privateInput)
            try input.fileHandleForWriting.close()
            let result = output.fileHandleForReading.readDataToEndOfFile()
            process.waitUntilExit()
            return (process.terminationStatus, result)
        }
        let archive = temporary.appendingPathComponent("update.zip")
        let data = Data("test update contents".utf8)
        try data.write(to: archive)
        let (status, output) = try signTool(["-p", archive.path])
        precondition(status == 0)
        let signatureString = String(data: output, encoding: .utf8)!.trimmingCharacters(in: .whitespacesAndNewlines)
        let signature = Data(base64Encoded: signatureString)!
        precondition(key.publicKey.isValidSignature(signature, for: data))
        precondition(!key.publicKey.isValidSignature(signature, for: Data("tampered".utf8)))
        precondition(!Curve25519.Signing.PrivateKey().publicKey.isValidSignature(signature, for: data))
        let feed = temporary.appendingPathComponent("appcast.xml")
        try Data("<?xml version=\"1.0\"?><rss version=\"2.0\"><channel><title>Palette</title></channel></rss>".utf8).write(to: feed)
        let signed = try signTool([feed.path])
        precondition(signed.0 == 0)
        let verified = try signTool(["--verify", feed.path])
        precondition(verified.0 == 0)
        var xml = try String(contentsOf: feed, encoding: .utf8)
        xml = xml.replacingOccurrences(of: "<title>Palette</title>", with: "<title>Tampered</title>")
        try xml.write(to: feed, atomically: true, encoding: .utf8)
        let tampered = try signTool(["--verify", feed.path])
        precondition(tampered.0 != 0)
        print("Passed Ed25519 signing, archive tampering, wrong-key rejection, and signed-feed tampering tests.")
    }
}
