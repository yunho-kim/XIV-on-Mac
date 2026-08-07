//
//  LoginCredentials.swift
//  XIV on Mac
//
//  Created by Marc-Aurel Zent on 02.02.22.
//

import Foundation
import KeychainAccess
import OrderedCollections

public struct LoginCredentials {
    static let squareServer = "https://secure.square-enix.com"
    static let koreanServer = "https://newlauncher.ff14.co.kr"
    let username: String
    let password: String
    var oneTimePassword: String?
    let region: FFXIVRegion

    public init(username: String) {
        self.username = username
        password = ""
        oneTimePassword = nil
        region = Settings.region
    }

    public init(
        username: String, password: String, oneTimePassword: String? = nil
    ) {
        self.username = username
        self.password = password
        self.oneTimePassword = oneTimePassword
        region = Settings.region
    }

    private init(username: String, password: String, region: FFXIVRegion) {
        self.username = username
        self.password = password
        oneTimePassword = nil
        self.region = region
    }

    static func server(for region: FFXIVRegion) -> String {
        region == .korea ? koreanServer : squareServer
    }

    static func storedLogin(
        username: String, region: FFXIVRegion = Settings.region
    ) -> LoginCredentials? {
        let keychain = Keychain(
            server: server(for: region), protocolType: .https)
        guard
            case let storedPassword?? =
                ((try? keychain.get(username)) as String??)
        else {
            return nil
        }
        return LoginCredentials(
            username: username, password: storedPassword, region: region)
    }

    static func deleteLogin(
        username: String, region: FFXIVRegion = Settings.region
    ) {
        let keychain = Keychain(
            server: server(for: region), protocolType: .https)
        keychain[username] = nil
    }

    public func saveLogin() {
        let keychain = Keychain(
            server: LoginCredentials.server(for: region), protocolType: .https)
        keychain[username] = password
    }

    public func deleteLogin() {
        LoginCredentials.deleteLogin(username: username, region: region)
    }

    static var accounts: [LoginCredentials] {
        let region = Settings.region
        let keychain = Keychain(
            server: server(for: region), protocolType: .https)
        return keychain.allKeys().compactMap {
            storedLogin(username: $0, region: region)
        }
            .filter { !$0.username.contains(" ") }
    }
}
