//
//  GameVersionDetector.swift
//  Azeroth Launcher
//
//  Created by Матвей on 07.11.2026.
//

import Foundation

struct DetectedGameVersion {
    let edition: GameEdition
    let major: Int
    let minor: Int
    let patch: Int
    let build: Int

    var versionString: String {
        "\(major).\(minor).\(patch).\(build)"
    }
}

struct GameVersionDetector {
    private let knownBuilds: [Int: GameEdition] = [
        12340: .wrath,
        15595: .cataclysm,
        18414: .pandaria
    ]

    func detect(at executableURL: URL) throws -> DetectedGameVersion {
        let data = try Data(contentsOf: executableURL)

        guard let version = readVersionResource(from: data) else {
            throw DetectionError.versionResourceNotFound
        }

        guard let edition = knownBuilds[version.build] else {
            throw DetectionError.unsupportedBuild(version.build)
        }

        return DetectedGameVersion(
            edition: edition,
            major: version.major,
            minor: version.minor,
            patch: version.patch,
            build: version.build
        )
    }

    private func readVersionResource(from data: Data) -> (major: Int, minor: Int, patch: Int, build: Int)? {
        guard data.count >= 64,
              data.readUInt16LE(at: 0) == 0x5A4D,
              let peOffset = data.readUInt32LE(at: 0x3C)
        else {
            return nil
        }

        let pe = Int(peOffset)

        guard data.readUInt32LE(at: pe) == 0x00004550,
              let sectionCount = data.readUInt16LE(at: pe + 6),
              let optionalHeaderSize = data.readUInt16LE(at: pe + 20)
        else {
            return nil
        }

        let optionalHeader = pe + 24

        guard let magic = data.readUInt16LE(at: optionalHeader) else {
            return nil
        }

        let dataDirectoryOffset: Int

        switch magic {
        case 0x10B: dataDirectoryOffset = optionalHeader + 96
        case 0x20B: dataDirectoryOffset = optionalHeader + 112

        default:
            return nil
        }

        let resourceEntry = dataDirectoryOffset + 2 * 8

        guard let resourceRVA = data.readUInt32LE(at: resourceEntry),
              let resourceSize = data.readUInt32LE(at: resourceEntry + 4),
              resourceRVA != 0,
              resourceSize > 0
        else {
            return nil
        }

        let sectionTable = optionalHeader + Int(optionalHeaderSize)
        var resourceFileOffset: Int?

        for index in 0..<Int(sectionCount) {
            let section = sectionTable + index * 40
            guard let virtualSize = data.readUInt32LE(at: section + 8),
                  let virtualAddress = data.readUInt32LE(at: section + 12),
                  let rawSize = data.readUInt32LE(at: section + 16),
                  let rawOffset = data.readUInt32LE(at: section + 20)
            else {
                return nil
            }

            let size = max(virtualSize, rawSize)
            if resourceRVA >= virtualAddress,
               resourceRVA < virtualAddress + size {
                let delta = resourceRVA - virtualAddress
                guard delta < rawSize else {
                    return nil
                }
                resourceFileOffset = Int(rawOffset + delta)
                break
            }
        }

        guard let resourceOffset = resourceFileOffset else {
            return nil
        }

        guard let versionDirectory = findResource(
            in: data,
            root: resourceOffset,
            directory: resourceOffset,
            targetID: 16
        ) else {
            return nil
        }

        guard let nameDirectory = firstResourceDirectory(
            in: data,
            root: resourceOffset,
            directory: versionDirectory
        ) else {
            return nil
        }

        guard let languageEntry = firstResourceDataEntry(
            in: data,
            root: resourceOffset,
            directory: nameDirectory
        ) else {
            return nil
        }

        guard let versionRVA = data.readUInt32LE(at: languageEntry),
              let versionSize = data.readUInt32LE(at: languageEntry + 4)
        else {
            return nil
        }

        guard let versionOffset = convertRVA(
            versionRVA,
            in: data,
            pe: pe,
            optionalHeader: optionalHeader,
            optionalHeaderSize: Int(optionalHeaderSize),
            sectionCount: Int(sectionCount)
        ) else {
            return nil
        }

        guard versionSize > 0,
              versionSize <= data.count - versionOffset
        else {
            return nil
        }

        let versionData = data.subdata(
            in: versionOffset..<(versionOffset + Int(versionSize))
        )

        return parseFixedFileInfo(versionData)
    }

    private func findResource( in data: Data, root: Int, directory: Int,targetID: UInt16) -> Int? {
        guard let namedCount = data.readUInt16LE(at: directory + 12),
              let idCount = data.readUInt16LE(at: directory + 14)
        else {
            return nil
        }

        let entries = directory + 16

        for index in 0..<Int(namedCount + idCount) {
            let entry = entries + index * 8
            guard let name = data.readUInt32LE(at: entry),
                  let offset = data.readUInt32LE(at: entry + 4)
            else {
                return nil
            }
            let id = name & 0xFFFF
            guard name & 0x80000000 == 0,
                  id == UInt32(targetID),
                  offset & 0x80000000 != 0
            else {
                continue
            }
            return root + Int(offset & 0x7FFFFFFF)
        }

        return nil
    }

    private func firstResourceDirectory(in data: Data, root: Int, directory: Int) -> Int? {
        guard let count = data.readUInt16LE(at: directory + 14),
              count > 0
        else {
            return nil
        }
        let entry = directory + 16
        guard let offset = data.readUInt32LE(at: entry + 4),
              offset & 0x80000000 != 0
        else {
            return nil
        }
        return root + Int(offset & 0x7FFFFFFF)
    }

    private func firstResourceDataEntry(in data: Data, root: Int, directory: Int) -> Int? {
        guard let namedCount = data.readUInt16LE(at: directory + 12),
              let idCount = data.readUInt16LE(at: directory + 14),
              namedCount + idCount > 0
        else {
            return nil
        }

        let entry = directory + 16
        guard let offset = data.readUInt32LE(at: entry + 4),
              offset & 0x80000000 == 0
        else {
            return nil
        }

        return root + Int(offset)
    }
    
    private func convertRVA(
        _ rva: UInt32,
        in data: Data,
        pe: Int,
        optionalHeader: Int,
        optionalHeaderSize: Int,
        sectionCount: Int
    ) -> Int? {
        let sectionTable = optionalHeader + optionalHeaderSize
        for index in 0..<sectionCount {
            let section = sectionTable + index * 40
            guard let virtualSize = data.readUInt32LE(at: section + 8),
                  let virtualAddress = data.readUInt32LE(at: section + 12),
                  let rawSize = data.readUInt32LE(at: section + 16),
                  let rawOffset = data.readUInt32LE(at: section + 20)
            else {
                return nil
            }

            let size = max(virtualSize, rawSize)
            if rva >= virtualAddress,
               rva < virtualAddress + size {
                let delta = rva - virtualAddress
                guard delta < rawSize else {
                    return nil
                }
                return Int(rawOffset + delta)
            }
        }
        return nil
    }

    private func parseFixedFileInfo( _ data: Data) -> (major: Int, minor: Int, patch: Int, build: Int)? {
        let signature: UInt32 = 0xFEEF04BD
        guard data.count >= 52 else {
            return nil
        }
        for offset in stride(from: 0, through: data.count - 52, by: 4) {
            guard data.readUInt32LE(at: offset) == signature,
                  let versionMS = data.readUInt32LE(at: offset + 8),
                  let versionLS = data.readUInt32LE(at: offset + 12)
            else {
                continue
            }
            let major = Int(versionMS >> 16)
            let minor = Int(versionMS & 0xFFFF)
            let patch = Int(versionLS >> 16)
            let build = Int(versionLS & 0xFFFF)
            guard major > 0, build > 0 else {
                continue
            }
            return (major, minor, patch, build)
        }

        return nil
    }

    enum DetectionError: LocalizedError {
        case versionResourceNotFound
        case unsupportedBuild(Int)
        var errorDescription: String? {
            switch self {
            case .versionResourceNotFound:
                return "Не удалось прочитать версию Wow.exe."
            case .unsupportedBuild(let build):
                return "Неподдерживаемая версия клиента. Build: \(build)"
            }
        }
    }
}

private extension Data {
    func readUInt16LE(at offset: Int) -> UInt16? {
        guard offset >= 0, offset + 2 <= count else {
            return nil
        }

        let byte0 = UInt16(self[offset])
        let byte1 = UInt16(self[offset + 1])
        
        return byte0 | (byte1 << 8)
    }

    func readUInt32LE(at offset: Int) -> UInt32? {
        guard offset >= 0, offset + 4 <= count else {
            return nil
        }
        let byte0 = UInt32(self[offset])
        let byte1 = UInt32(self[offset + 1])
        let byte2 = UInt32(self[offset + 2])
        let byte3 = UInt32(self[offset + 3])
        
        return byte0
            | (byte1 << 8)
            | (byte2 << 16)
            | (byte3 << 24)
    }
}
