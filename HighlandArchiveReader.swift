// HighlandArchiveReader.swift
// Highland (quoteunquoteapps.com) saves .highland documents as a zip-
// compressed TextBundle: a "text.fountain" / "text.markdown" / "text.txt"
// entry holding the actual screenplay, alongside info.json and an optional
// assets/ folder. This reads just enough of the zip's central directory to
// pull that one text entry back out — not a general-purpose archive library,
// and no third-party dependency: DEFLATE decoding uses Apple's system
// Compression framework.

import Foundation
import Compression

struct HighlandArchiveReader {

    enum ReaderError: LocalizedError {
        case notAZipArchive
        case entryNotFound
        case decompressionFailed
        case invalidText

        var errorDescription: String? {
            switch self {
            case .notAZipArchive:      return "isn't a valid zip archive"
            case .entryNotFound:       return "has no text.fountain, text.markdown, or text.txt entry inside it"
            case .decompressionFailed: return "couldn't be decompressed"
            case .invalidText:         return "contains text that isn't valid UTF-8"
            }
        }
    }

    /// Extracts the Fountain/Markdown/plain-text screenplay body from a
    /// Highland document.
    static func extractScreenplayText(from zipData: Data) throws -> String {
        let entries = try centralDirectoryEntries(in: zipData)
        let candidateNames = ["text.fountain", "text.markdown", "text.txt"]
        let entry = candidateNames
            .compactMap { name in entries.first { $0.name == name || $0.name.hasSuffix("/" + name) } }
            .first
        guard let entry else { throw ReaderError.entryNotFound }

        let raw = try fileData(for: entry, in: zipData)
        guard let text = String(data: raw, encoding: .utf8) else { throw ReaderError.invalidText }
        return text
    }

    // MARK: - Zip structures

    private struct ZipEntry {
        let name: String
        let compressionMethod: UInt16
        let compressedSize: Int
        let uncompressedSize: Int
        let localHeaderOffset: Int
    }

    private static let eocdSignature: UInt32               = 0x0605_4b50
    private static let centralDirectorySignature: UInt32   = 0x0201_4b50
    private static let localFileHeaderSignature: UInt32    = 0x0403_4b50

    private static func centralDirectoryEntries(in data: Data) throws -> [ZipEntry] {
        guard let eocdOffset = findEOCD(in: data) else { throw ReaderError.notAZipArchive }

        let entryCount             = Int(readUInt16(data, at: eocdOffset + 10))
        let centralDirectorySize   = Int(readUInt32(data, at: eocdOffset + 12))
        let centralDirectoryOffset = Int(readUInt32(data, at: eocdOffset + 16))
        guard centralDirectoryOffset >= 0, centralDirectoryOffset + centralDirectorySize <= data.count else {
            throw ReaderError.notAZipArchive
        }

        var entries: [ZipEntry] = []
        var cursor = centralDirectoryOffset
        for _ in 0..<entryCount {
            guard cursor + 46 <= data.count, readUInt32(data, at: cursor) == centralDirectorySignature else { break }

            let compressionMethod = readUInt16(data, at: cursor + 10)
            let compressedSize    = Int(readUInt32(data, at: cursor + 20))
            let uncompressedSize  = Int(readUInt32(data, at: cursor + 24))
            let nameLength         = Int(readUInt16(data, at: cursor + 28))
            let extraLength        = Int(readUInt16(data, at: cursor + 30))
            let commentLength      = Int(readUInt16(data, at: cursor + 32))
            let localHeaderOffset  = Int(readUInt32(data, at: cursor + 42))

            let nameStart = cursor + 46
            let nameEnd   = nameStart + nameLength
            guard nameEnd <= data.count else { break }
            let name = String(data: data.subdata(in: nameStart..<nameEnd), encoding: .utf8) ?? ""

            entries.append(ZipEntry(
                name: name, compressionMethod: compressionMethod,
                compressedSize: compressedSize, uncompressedSize: uncompressedSize,
                localHeaderOffset: localHeaderOffset
            ))

            cursor = nameStart + nameLength + extraLength + commentLength
        }
        return entries
    }

    private static func fileData(for entry: ZipEntry, in data: Data) throws -> Data {
        let offset = entry.localHeaderOffset
        guard offset + 30 <= data.count, readUInt32(data, at: offset) == localFileHeaderSignature else {
            throw ReaderError.notAZipArchive
        }
        let nameLength  = Int(readUInt16(data, at: offset + 26))
        let extraLength = Int(readUInt16(data, at: offset + 28))
        let dataStart = offset + 30 + nameLength + extraLength
        let dataEnd   = dataStart + entry.compressedSize
        guard dataStart >= 0, dataEnd <= data.count else { throw ReaderError.notAZipArchive }
        let compressed = data.subdata(in: dataStart..<dataEnd)

        switch entry.compressionMethod {
        case 0:   // stored — no compression
            return compressed
        case 8:   // deflate
            guard let inflated = inflate(compressed, expectedSize: entry.uncompressedSize) else {
                throw ReaderError.decompressionFailed
            }
            return inflated
        default:
            throw ReaderError.decompressionFailed
        }
    }

    /// Scans backward from the end of the file for the End-Of-Central-
    /// Directory signature — the archive comment field (up to 65535 bytes)
    /// means it isn't necessarily the very last 22 bytes.
    private static func findEOCD(in data: Data) -> Int? {
        guard data.count >= 22 else { return nil }
        let searchFloor = max(0, data.count - 22 - 65535)
        var offset = data.count - 22
        while offset >= searchFloor {
            if readUInt32(data, at: offset) == eocdSignature { return offset }
            offset -= 1
        }
        return nil
    }

    private static func inflate(_ compressed: Data, expectedSize: Int) -> Data? {
        guard expectedSize > 0 else { return Data() }
        var output = Data(count: expectedSize)
        let written = output.withUnsafeMutableBytes { destRaw -> Int in
            compressed.withUnsafeBytes { srcRaw -> Int in
                guard let dest = destRaw.bindMemory(to: UInt8.self).baseAddress,
                      let src  = srcRaw.bindMemory(to: UInt8.self).baseAddress else { return 0 }
                // Apple's COMPRESSION_ZLIB algorithm here means raw DEFLATE
                // (no zlib header/trailer) — exactly what's stored in a zip
                // entry with compression method 8.
                return compression_decode_buffer(dest, expectedSize, src, compressed.count, nil, COMPRESSION_ZLIB)
            }
        }
        guard written == expectedSize else { return nil }
        return output
    }

    // MARK: - Little-endian reads

    private static func readUInt16(_ data: Data, at offset: Int) -> UInt16 {
        guard offset >= 0, offset + 2 <= data.count else { return 0 }
        let base = data.startIndex + offset
        return UInt16(data[base]) | (UInt16(data[base + 1]) << 8)
    }

    private static func readUInt32(_ data: Data, at offset: Int) -> UInt32 {
        guard offset >= 0, offset + 4 <= data.count else { return 0 }
        let base = data.startIndex + offset
        return UInt32(data[base])
            | (UInt32(data[base + 1]) << 8)
            | (UInt32(data[base + 2]) << 16)
            | (UInt32(data[base + 3]) << 24)
    }
}
