import Foundation

struct MachoInfo {
    let fileName: String
    let fileSize: Int
    let archs: [String]   // напр. ["arm64"]
    let isFat: Bool
    let looksLikeDylib: Bool
    let rawDescription: String
}

enum MachoError: Error, LocalizedError {
    case notFound, tooSmall, unknownMagic(UInt32), readFail(String)
    var errorDescription: String? {
        switch self {
        case .notFound: return "файл не найден"
        case .tooSmall: return "файл меньше Mach-O заголовка (битый/не dylib)"
        case .unknownMagic(let m): return String(format: "неизвестный magic 0x%08X — не Mach-O (может это текст/zip?)", m)
        case .readFail(let s): return "ошибка чтения: \(s)"
        }
    }
}

/// Читает Mach-O заголовок без внешних утилит — чтобы в логе сразу было видно
/// «не та архитектура» ещё ДО вызова dlopen.
enum MachoInspector {
    // MH magic
    private static let MH_MAGIC: UInt32    = 0xfeedface
    private static let MH_MAGIC_64: UInt32 = 0xfeedfacf
    private static let FAT_MAGIC: UInt32   = 0xcafebabe
    private static let FAT_CIGAM: UInt32   = 0xbebafeca
    // cputype
    private static let CPU_ARM64: Int32  = Int32(bitPattern: 0x0100000C)
    private static let CPU_X86_64: Int32 = Int32(bitPattern: 0x01000007)
    private static let CPU_ARM64_32: Int32 = Int32(bitPattern: 0x0200000C)

    static func inspect(url: URL) -> Result<MachoInfo, MachoError> {
        let fm = FileManager.default
        guard fm.fileExists(atPath: url.path) else { return .failure(.notFound) }
        guard let attrs = try? fm.attributesOfItem(atPath: url.path),
              let size = attrs[.size] as? Int else {
            return .failure(.readFail("нет доступа к размеру"))
        }
        guard let handle = try? FileHandle(forReadingFrom: url) else {
            return .failure(.readFail("не открывается FileHandle"))
        }
        defer { try? handle.close() }
        guard let head = try? handle.read(upToCount: 4096), head.count >= 8 else {
            return .failure(.tooSmall)
        }
        let magicBE: UInt32 = head.withUnsafeBytes { $0.load(as: UInt32.self).bigEndian }
        let magicLE: UInt32 = head.withUnsafeBytes { $0.load(as: UInt32.self).littleEndian }

        func cpuName(_ t: Int32) -> String {
            switch t {
            case CPU_ARM64: return "arm64"
            case CPU_X86_64: return "x86_64"
            case CPU_ARM64_32: return "arm64_32"
            case 12: return "arm"
            default: return String(format: "cpu(0x%08X)", UInt32(bitPattern: t))
            }
        }

        // FAT binary — внутри несколько архитектур
        if magicBE == FAT_MAGIC || magicBE == FAT_CIGAM || magicLE == FAT_MAGIC {
            // nfat_arch идёт big-endian после magic
            guard head.count >= 8 else { return .failure(.tooSmall) }
            let nfat: UInt32 = head.withUnsafeBytes { ptr -> UInt32 in
                let raw = ptr.baseAddress!.advanced(by: 4).assumingMemoryBound(to: UInt32.self).pointee
                return UInt32(bigEndian: raw)
            }
            var archs: [String] = []
            // Каждый fat_arch = 20 байт: cputype(4) cpusubtype(4) offset(4) size(4) align(4)
            let count = min(Int(nfat), 8)
            for i in 0..<count {
                let off = 8 + i * 20
                guard head.count >= off + 4 else { break }
                let raw: Int32 = head.withUnsafeBytes { ptr -> Int32 in
                    let v = ptr.baseAddress!.advanced(by: off).assumingMemoryBound(to: UInt32.self).pointee
                    return Int32(bitPattern: UInt32(bigEndian: v))
                }
                archs.append(cpuName(raw))
            }
            let hasArm64 = archs.contains("arm64")
            let list = archs.joined(separator: ",")
            let armMsg = hasArm64 ? "arm64 есть" : "arm64 НЕТ - на девайсе не запустится"
            return .success(MachoInfo(
                fileName: url.lastPathComponent, fileSize: size, archs: archs,
                isFat: true, looksLikeDylib: true,
                rawDescription: "FAT Mach-O (" + list + ") " + armMsg))
        }

        // Thin Mach-O
        let magic: UInt32 = head.withUnsafeBytes { $0.load(as: UInt32.self) }
        if magic == MH_MAGIC_64 || magic == MH_MAGIC {
            guard head.count >= 16 else { return .failure(.tooSmall) }
            let cputype: Int32 = head.withUnsafeBytes { ptr -> Int32 in
                ptr.baseAddress!.advanced(by: 4).assumingMemoryBound(to: Int32.self).pointee
            }
            let filetype: UInt32 = head.withUnsafeBytes { ptr -> UInt32 in
                ptr.baseAddress!.advanced(by: 12).assumingMemoryBound(to: UInt32.self).pointee
            }
            // MH_DYLIB = 0x6, MH_BUNDLE = 0x8
            let isDylib = (filetype == 0x6 || filetype == 0x8)
            let arch = cpuName(cputype)
            let ftText: String
            if filetype == 0x6 {
                ftText = "DYLIB ok"
            } else if filetype == 0x8 {
                ftText = "BUNDLE (тоже грузится)"
            } else {
                ftText = "type " + String(filetype) + " - НЕ dylib"
            }
            return .success(MachoInfo(
                fileName: url.lastPathComponent, fileSize: size, archs: [arch],
                isFat: false, looksLikeDylib: isDylib,
                rawDescription: "Mach-O 64-bit arch=" + arch + " filetype=" + ftText))
        }
        return .failure(.unknownMagic(magic))
    }
}
