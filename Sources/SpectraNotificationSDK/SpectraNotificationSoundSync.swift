import CryptoKit
import Foundation

public protocol SpectraNotificationSoundDownloading: Sendable {
    func data(from url: URL) async throws -> Data
}

public struct URLSessionSpectraNotificationSoundDownloader: SpectraNotificationSoundDownloading {
    private let session: URLSession

    public init(session: URLSession = .shared) {
        self.session = session
    }

    public func data(from url: URL) async throws -> Data {
        let (data, response) = try await session.data(from: url)
        guard let http = response as? HTTPURLResponse,
              (200..<300).contains(http.statusCode) else {
            throw URLError(.badServerResponse)
        }
        return data
    }
}

public struct SpectraInstalledNotificationSound: Codable, Equatable, Sendable {
    public let soundID: String
    public let version: Int
    public let fileName: String
    public let checksum: String
    public let installedAt: Date

    public init(soundID: String, version: Int, fileName: String, checksum: String, installedAt: Date) {
        self.soundID = soundID
        self.version = version
        self.fileName = fileName
        self.checksum = checksum
        self.installedAt = installedAt
    }
}

public protocol SpectraNotificationSoundInstallationStore: Sendable {
    func installedSound(soundID: String) async throws -> SpectraInstalledNotificationSound?
    func saveInstalledSound(_ sound: SpectraInstalledNotificationSound) async throws
    func removeInstalledSound(soundID: String) async throws
}

public actor InMemorySpectraNotificationSoundInstallationStore: SpectraNotificationSoundInstallationStore {
    private var sounds: [String: SpectraInstalledNotificationSound]

    public init(sounds: [SpectraInstalledNotificationSound] = []) {
        self.sounds = Dictionary(uniqueKeysWithValues: sounds.map { ($0.soundID, $0) })
    }

    public func installedSound(soundID: String) async throws -> SpectraInstalledNotificationSound? {
        sounds[soundID]
    }

    public func saveInstalledSound(_ sound: SpectraInstalledNotificationSound) async throws {
        sounds[sound.soundID] = sound
    }

    public func removeInstalledSound(soundID: String) async throws {
        sounds[soundID] = nil
    }
}

public final class UserDefaultsSpectraNotificationSoundInstallationStore:
    SpectraNotificationSoundInstallationStore,
    @unchecked Sendable
{
    private let defaults: UserDefaults
    private let key: String
    private let encoder = JSONEncoder()
    private let decoder = JSONDecoder()

    public init(
        defaults: UserDefaults = .standard,
        key: String = "com.spectra.notification.installed-sounds"
    ) {
        self.defaults = defaults
        self.key = key
        encoder.dateEncodingStrategy = .iso8601
        decoder.dateDecodingStrategy = .iso8601
    }

    public func installedSound(soundID: String) async throws -> SpectraInstalledNotificationSound? {
        try load()[soundID]
    }

    public func saveInstalledSound(_ sound: SpectraInstalledNotificationSound) async throws {
        var sounds = try load()
        sounds[sound.soundID] = sound
        try save(sounds)
    }

    public func removeInstalledSound(soundID: String) async throws {
        var sounds = try load()
        sounds[soundID] = nil
        try save(sounds)
    }

    private func load() throws -> [String: SpectraInstalledNotificationSound] {
        guard let data = defaults.data(forKey: key) else { return [:] }
        return try decoder.decode([String: SpectraInstalledNotificationSound].self, from: data)
    }

    private func save(_ sounds: [String: SpectraInstalledNotificationSound]) throws {
        defaults.set(try encoder.encode(sounds), forKey: key)
    }
}

public enum SpectraNotificationSoundSyncStatus: String, Codable, Equatable, Sendable {
    case installed
    case skipped
    case failed
}

public struct SpectraNotificationSoundSyncResult: Equatable, Sendable {
    public let soundID: String
    public let version: Int
    public let fileName: String
    public let status: SpectraNotificationSoundSyncStatus
    public let failureReason: String?

    public init(
        soundID: String,
        version: Int,
        fileName: String,
        status: SpectraNotificationSoundSyncStatus,
        failureReason: String? = nil
    ) {
        self.soundID = soundID
        self.version = version
        self.fileName = fileName
        self.status = status
        self.failureReason = failureReason
    }
}

public final class SpectraNotificationSoundSyncManager: @unchecked Sendable {
    public enum ValidationError: Error, Equatable, Sendable {
        case insecureDownloadURL
        case invalidFileName
        case unsupportedFormat
        case checksumMismatch
        case fileTooLarge
        case disabled
    }

    public static let maximumDownloadBytes = 10 * 1024 * 1024

    private let client: SpectraNotificationClient
    private let downloader: any SpectraNotificationSoundDownloading
    private let installationStore: any SpectraNotificationSoundInstallationStore
    private let fileManager: FileManager
    private let soundsDirectory: URL
    private let now: @Sendable () -> Date

    public init(
        client: SpectraNotificationClient,
        downloader: any SpectraNotificationSoundDownloading = URLSessionSpectraNotificationSoundDownloader(),
        installationStore: any SpectraNotificationSoundInstallationStore =
            UserDefaultsSpectraNotificationSoundInstallationStore(),
        fileManager: FileManager = .default,
        soundsDirectory: URL? = nil,
        now: @escaping @Sendable () -> Date = { Date() }
    ) {
        self.client = client
        self.downloader = downloader
        self.installationStore = installationStore
        self.fileManager = fileManager
        self.soundsDirectory = soundsDirectory ?? Self.defaultSoundsDirectory(fileManager: fileManager)
        self.now = now
    }

    public static func defaultSoundsDirectory(fileManager: FileManager = .default) -> URL {
        fileManager.urls(for: .libraryDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("Sounds", isDirectory: true)
    }

    public func synchronize() async throws -> [SpectraNotificationSoundSyncResult] {
        let manifest = try await client.fetchSoundManifest()
        var results: [SpectraNotificationSoundSyncResult] = []
        for sound in manifest.sounds {
            results.append(await synchronize(sound))
        }
        return results
    }

    public func localURL(for sound: SpectraNotificationSound) -> URL {
        soundsDirectory.appendingPathComponent(sound.fileName)
    }

    public func needsDownload(_ sound: SpectraNotificationSound) async throws -> Bool {
        guard sound.enabled else { throw ValidationError.disabled }
        try validateMetadata(sound)
        let destination = localURL(for: sound)
        guard fileManager.fileExists(atPath: destination.path) else {
            return true
        }
        let installed = try await installationStore.installedSound(soundID: sound.id)
        return installed?.version != sound.version
            || installed?.fileName != sound.fileName
            || installed?.checksum != sound.checksum
    }

    public static func sha256Hex(_ data: Data) -> String {
        SHA256.hash(data: data).map { String(format: "%02x", $0) }.joined()
    }

    public static func checksumMatches(_ data: Data, checksum: String) -> Bool {
        let trimmed = checksum.trimmingCharacters(in: .whitespacesAndNewlines)
        let value = trimmed.hasPrefix("sha256:") ? String(trimmed.dropFirst("sha256:".count)) : trimmed
        return value.lowercased() == sha256Hex(data)
            || value == Data(SHA256.hash(data: data)).base64EncodedString()
    }

    private func synchronize(_ sound: SpectraNotificationSound) async -> SpectraNotificationSoundSyncResult {
        do {
            if try await !needsDownload(sound) {
                return .init(
                    soundID: sound.id,
                    version: sound.version,
                    fileName: sound.fileName,
                    status: .skipped
                )
            }
            try await install(sound)
            try await client.reportSoundInstallation(
                soundId: sound.id,
                version: sound.version,
                fileName: sound.fileName
            )
            return .init(soundID: sound.id, version: sound.version, fileName: sound.fileName, status: .installed)
        } catch {
            return .init(
                soundID: sound.id,
                version: sound.version,
                fileName: sound.fileName,
                status: .failed,
                failureReason: String(describing: error)
            )
        }
    }

    private func install(_ sound: SpectraNotificationSound) async throws {
        try validateMetadata(sound)
        let data = try await downloader.data(from: sound.downloadURL)
        guard data.count <= Self.maximumDownloadBytes else {
            throw ValidationError.fileTooLarge
        }
        guard Self.checksumMatches(data, checksum: sound.checksum) else {
            throw ValidationError.checksumMismatch
        }
        try validateMagicBytes(data, fileName: sound.fileName)

        try fileManager.createDirectory(at: soundsDirectory, withIntermediateDirectories: true)
        let destination = localURL(for: sound)
        let stagingURL = soundsDirectory
            .appendingPathComponent(".\(UUID().uuidString).tmp.\(destination.pathExtension)")
        defer { try? fileManager.removeItem(at: stagingURL) }
        try data.write(to: stagingURL, options: [.atomic])
        if fileManager.fileExists(atPath: destination.path) {
            _ = try fileManager.replaceItemAt(destination, withItemAt: stagingURL)
        } else {
            try fileManager.moveItem(at: stagingURL, to: destination)
        }
        try await installationStore.saveInstalledSound(.init(
            soundID: sound.id,
            version: sound.version,
            fileName: sound.fileName,
            checksum: sound.checksum,
            installedAt: now()
        ))
    }

    private func validateMetadata(_ sound: SpectraNotificationSound) throws {
        guard sound.enabled else { throw ValidationError.disabled }
        guard sound.downloadURL.scheme?.lowercased() == "https",
              sound.downloadURL.host?.isEmpty == false else {
            throw ValidationError.insecureDownloadURL
        }
        guard Self.isValidSoundFileName(sound.fileName) else {
            throw ValidationError.invalidFileName
        }
    }

    private static func isValidSoundFileName(_ fileName: String) -> Bool {
        guard fileName.utf8.count <= 120,
              fileName.range(of: #"^[A-Za-z0-9][A-Za-z0-9._-]*\.(caf|wav|aiff)$"#, options: .regularExpression) != nil else {
            return false
        }
        return true
    }

    private func validateMagicBytes(_ data: Data, fileName: String) throws {
        switch fileName.lowercased().split(separator: ".").last {
        case "caf":
            guard data.starts(with: Data("caff".utf8)) else { throw ValidationError.unsupportedFormat }
        case "wav":
            guard data.count >= 12,
                  data.prefix(4) == Data("RIFF".utf8),
                  data.dropFirst(8).prefix(4) == Data("WAVE".utf8) else {
                throw ValidationError.unsupportedFormat
            }
        case "aiff":
            guard data.count >= 12,
                  data.prefix(4) == Data("FORM".utf8),
                  ["AIFF", "AIFC"].contains(String(decoding: data.dropFirst(8).prefix(4), as: UTF8.self)) else {
                throw ValidationError.unsupportedFormat
            }
        default:
            throw ValidationError.unsupportedFormat
        }
    }
}
