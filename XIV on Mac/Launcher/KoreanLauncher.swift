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
