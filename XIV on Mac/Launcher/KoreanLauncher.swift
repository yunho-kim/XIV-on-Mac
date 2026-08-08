//
//  KoreanLauncher.swift
//  XIV on Mac
//
//  Korean launcher NativeAOT bridge. Authentication secrets and the game token
//  remain inside the native launcher module.
//

import Foundation
import XIVLauncher

struct KoreanInteropResponse: Decodable {
    let success: Bool
    let state: String
    let errorCode: String?
    let message: String?
    let stage: String?
    let serverCode: String?
    let login: KoreanLoginPayload?
    let patch: KoreanPatchPayload?
    let process: ProcessInformation?

    enum CodingKeys: String, CodingKey {
        case success = "Success"
        case state = "State"
        case errorCode = "ErrorCode"
        case message = "Message"
        case stage = "Stage"
        case serverCode = "ServerCode"
        case login = "Login"
        case patch = "Patch"
        case process = "Process"
    }
}

struct KoreanLoginPayload: Decodable {
    let captchaImageBase64: String?
    let captchaMediaType: String?
    let otpRequired: Bool

    enum CodingKeys: String, CodingKey {
        case captchaImageBase64 = "CaptchaImageBase64"
        case captchaMediaType = "CaptchaMediaType"
        case otpRequired = "OtpRequired"
    }
}

struct KoreanPatchPayload: Decodable {
    let isFreshInstall: Bool
    let pendingPatches: [Patch]

    enum CodingKeys: String, CodingKey {
        case isFreshInstall = "IsFreshInstall"
        case pendingPatches = "PendingPatches"
    }
}

struct KoreanLauncherError: LocalizedError {
    let code: String
    let stage: String?
    let serverCode: String?
    let detail: String

    var errorDescription: String? {
        var components = [detail]
        if let stage, !stage.isEmpty {
            components.append("Stage: \(stage)")
        }
        if let serverCode, !serverCode.isEmpty {
            components.append("Code: \(serverCode)")
        }
        return components.joined(separator: "\n")
    }
}

enum KoreanLauncher {
    static func prepareLogin() throws -> KoreanLoginPayload {
        let response = try decode(koreanPrepareLogin())
        guard let login = response.login,
            login.captchaImageBase64 != nil
        else {
            throw invalidResponse()
        }
        return login
    }

    static func login(
        username: String, password: String, captchaCode: String
    ) throws -> KoreanLoginPayload {
        let response = try decode(
            koreanLogin(username, password, captchaCode))
        guard let login = response.login else {
            throw invalidResponse()
        }
        return login
    }

    static func submitOtp(_ otp: String) throws {
        _ = try decode(koreanSubmitOtp(otp))
    }

    static func pendingPatches() throws -> KoreanPatchPayload {
        let response = try decode(koreanGetPatches())
        guard let patch = response.patch else {
            throw invalidResponse()
        }
        return patch
    }

    static func startGame(dalamudOk: Bool) throws -> ProcessInformation {
        let response = try decode(koreanStartGame(dalamudOk))
        guard let process = response.process else {
            throw invalidResponse()
        }
        return process
    }

    static func resetSession() {
        koreanResetSession()
    }

    private static func decode(
        _ pointer: UnsafePointer<CChar>?
    ) throws -> KoreanInteropResponse {
        guard let pointer else {
            throw invalidResponse()
        }
        defer { freeNativeString(pointer) }

        let json = String(cString: pointer)
        guard let data = json.data(using: .utf8),
            let response = try? JSONDecoder().decode(
                KoreanInteropResponse.self, from: data)
        else {
            throw invalidResponse()
        }

        guard response.success else {
            throw KoreanLauncherError(
                code: response.errorCode ?? "UnknownError",
                stage: response.stage,
                serverCode: response.serverCode,
                detail: response.message
                    ?? "The Korean launcher operation failed.")
        }
        return response
    }

    private static func invalidResponse() -> KoreanLauncherError {
        KoreanLauncherError(
            code: "InvalidBridgeResponse",
            stage: nil,
            serverCode: nil,
            detail: "The Korean launcher returned an invalid response.")
    }
}

struct ConfigBackupResult: Decodable {
    let characterCount: Int
    let fileCount: Int
    let skippedFileCount: Int

    enum CodingKeys: String, CodingKey {
        case characterCount = "CharacterCount"
        case fileCount = "FileCount"
        case skippedFileCount = "SkippedFileCount"
    }
}

private struct ConfigBackupInteropResponse: Decodable {
    let success: Bool
    let errorCode: String?
    let message: String?
    let characterCount: Int
    let fileCount: Int
    let skippedFileCount: Int

    enum CodingKeys: String, CodingKey {
        case success = "Success"
        case errorCode = "ErrorCode"
        case message = "Message"
        case characterCount = "CharacterCount"
        case fileCount = "FileCount"
        case skippedFileCount = "SkippedFileCount"
    }
}

struct ConfigBackupError: LocalizedError {
    let code: String
    let detail: String

    var errorDescription: String? {
        switch code {
        case "NoCharacterSettings":
            return "내보낼 캐릭터 설정을 찾지 못했습니다. 게임에 접속해 캐릭터 설정을 먼저 생성해 주세요."
        case "InvalidArchive":
            return "선택한 파일이 손상되었거나 지원되는 FFXIV 설정 백업이 아닙니다."
        case "UnsupportedVersion":
            return "이 설정 백업의 버전은 아직 지원하지 않습니다."
        case "ArchiveTooLarge":
            return "설정 백업 파일이 허용된 크기를 초과했습니다."
        case "FileNotFound":
            return "선택한 설정 백업 파일을 찾지 못했습니다."
        case "ReadFailed":
            return "설정 백업 파일을 읽을 수 없습니다."
        case "WriteFailed", "InvalidDestination":
            return "선택한 위치에 설정 백업을 저장할 수 없습니다."
        case "RestoreFailed":
            return "설정을 복원하지 못했습니다. 변경된 파일은 가능한 범위에서 원래 상태로 되돌렸습니다."
        default:
            return detail
        }
    }
}

enum KoreanConfigBackup {
    static func exportBackup(
        configDirectory: URL,
        destination: URL
    ) throws -> ConfigBackupResult {
        try decode(
            exportConfigBackup(configDirectory.path, destination.path))
    }

    static func importBackup(
        configDirectory: URL,
        source: URL,
        preserveNewerFiles: Bool
    ) throws -> ConfigBackupResult {
        try decode(
            importConfigBackup(
                configDirectory.path,
                source.path,
                preserveNewerFiles))
    }

    private static func decode(
        _ pointer: UnsafePointer<CChar>?
    ) throws -> ConfigBackupResult {
        guard let pointer else {
            throw ConfigBackupError(
                code: "InvalidBridgeResponse",
                detail: "설정 백업 모듈에서 올바른 응답을 받지 못했습니다.")
        }
        defer { freeNativeString(pointer) }

        let json = String(cString: pointer)
        guard let data = json.data(using: .utf8),
            let response = try? JSONDecoder().decode(
                ConfigBackupInteropResponse.self,
                from: data)
        else {
            throw ConfigBackupError(
                code: "InvalidBridgeResponse",
                detail: "설정 백업 모듈에서 올바른 응답을 받지 못했습니다.")
        }

        guard response.success else {
            throw ConfigBackupError(
                code: response.errorCode ?? "InternalError",
                detail: response.message ?? "설정 백업 작업에 실패했습니다.")
        }

        return ConfigBackupResult(
            characterCount: response.characterCount,
            fileCount: response.fileCount,
            skippedFileCount: response.skippedFileCount)
    }
}
