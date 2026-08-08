//
//  SettingsGeneralTabView.swift
//  XIV on Mac
//
//  Created by Chris Backas on 1/14/23.
//

import SeeURL  // HTTPClient/Download speed limiter setting
import SwiftUI
import UniformTypeIdentifiers

struct SettingsGeneralTabView: View {
    @StateObject private var viewModel = ViewModel()

    var body: some View {
        ZStack(alignment: .bottomTrailing) {
            VStack {
                VStack {
                    HStack {
                        Text("한국 서버")
                            .font(.headline)

                        Spacer()
                    }

                    Text("이 빌드는 파이널판타지14 한국 서버 전용입니다. 언어, 플랫폼 및 계정 데이터는 한국 서버 설정으로 고정됩니다.")
                        .multilineTextAlignment(.leading)
                        .lineLimit(nil)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .font(.callout)
                }
                .padding([.leading, .trailing, .top])

                VStack(alignment: .leading, spacing: 8) {
                    HStack {
                        Text("사용자 설정 백업")
                            .font(.headline)

                        Spacer()
                    }

                    Text("HUD, 단축바, 장비 세트, 매크로 등 캐릭터별 설정을 공식 런처와 호환되는 FFXIVconf.fea 파일로 내보내거나 가져옵니다. 시스템 그래픽 설정과 스크린샷은 포함하지 않습니다.")
                        .multilineTextAlignment(.leading)
                        .lineLimit(nil)
                        .font(.callout)

                    HStack {
                        Toggle(
                            "백업보다 새로운 로컬 설정은 덮어쓰지 않기",
                            isOn: $viewModel.preserveNewerSettings)

                        Spacer()

                        if viewModel.backupOperationInProgress {
                            ProgressView()
                                .controlSize(.small)
                        }

                        Button("내보내기…") {
                            viewModel.exportConfigBackup()
                        }
                        .disabled(viewModel.backupOperationInProgress)

                        Button("가져오기…") {
                            viewModel.importConfigBackup()
                        }
                        .disabled(viewModel.backupOperationInProgress)
                    }

                    if !viewModel.backupStatus.isEmpty {
                        Text(viewModel.backupStatus)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
                .padding([.leading, .trailing, .top])

                VStack {
                    HStack {
                        Text("SETTINGS_GENERAL_TITLE_NETWORK")
                            .font(.headline)

                        Spacer()
                    }

                    HStack {
                        Toggle(isOn: $viewModel.limitDownloadEnabled) {
                            Text("SETTINGS_DOWNLOAD_LIMIT")
                        }

                        TextField(
                            "SETTINGS_DOWNLOAD_LIMIT_PLACEHOLDER",
                            text: $viewModel.limitDownloadSpeed
                        )
                        .fixedSize(horizontal: true, vertical: false)
                        .disabled(!viewModel.limitDownloadEnabled)

                        Text("SETTINGS_DOWNLOAD_LIMIT_UNITS")
                        Spacer()
                    }
                }
                .padding([.leading, .trailing, .top])

                HStack {
                    VStack {
                        HStack {
                            Text("SETTINGS_GENERAL_TITLE_INPUT")
                                .font(.headline)

                            Spacer()
                        }

                        HStack {
                            Picker(
                                "SETTINGS_GENERAL_INPUT_LEFT_OPTION",
                                selection: $viewModel.leftOptionIsAlt
                            ) {
                                Text(
                                    "SETTINGS_GENERAL_INPUT_BUTTON_WINDOWS_ALT"
                                ).tag(true)
                                Text(
                                    "SETTINGS_GENERAL_INPUT_BUTTON_MACOS_OPTION"
                                ).tag(false)
                            }

                            Picker(
                                "SETTINGS_GENERAL_INPUT_RIGHT_OPTION",
                                selection: $viewModel.rightOptionIsAlt
                            ) {
                                Text(
                                    "SETTINGS_GENERAL_INPUT_BUTTON_WINDOWS_ALT"
                                ).tag(true)
                                Text(
                                    "SETTINGS_GENERAL_INPUT_BUTTON_MACOS_OPTION"
                                ).tag(false)
                            }
                        }

                        HStack {
                            Picker(
                                "SETTINGS_GENERAL_INPUT_LEFT_COMMAND",
                                selection: $viewModel.leftCommandIsCtrl
                            ) {
                                Text("SETTINGS_GENERAL_INPUT_BUTTON_CTRL").tag(
                                    true)
                                Text("SETTINGS_GENERAL_INPUT_BUTTON_ALT").tag(
                                    false)
                            }

                            Picker(
                                "SETTINGS_GENERAL_INPUT_RIGHT_COMMAND",
                                selection: $viewModel.rightCommandIsCtrl
                            ) {
                                Text("SETTINGS_GENERAL_INPUT_BUTTON_CTRL").tag(
                                    true)
                                Text("SETTINGS_GENERAL_INPUT_BUTTON_ALT").tag(
                                    false)
                            }
                        }
                    }

                    Spacer(minLength: 140)
                }
                .padding([.leading, .trailing, .top])

                Spacer()
            }
            Image(nsImage: NSImage(named: "PrefsGeneral") ?? NSImage())
                .padding()
        }
        .alert(
            viewModel.backupAlertTitle,
            isPresented: $viewModel.showingBackupAlert
        ) {
            Button("확인", role: .cancel) {}
        } message: {
            Text(viewModel.backupAlertMessage)
        }
    }
}

struct SettingsGeneralTabView_Previews: PreviewProvider {
    static var previews: some View {
        SettingsGeneralTabView()
    }
}

extension SettingsGeneralTabView {
    @MainActor class ViewModel: ObservableObject {
        @Published var limitDownloadEnabled: Bool = HTTPClient.maxSpeed > 0 {
            didSet { updateHTTPMaxSpeed() }
        }

        @Published var limitDownloadSpeed: String = .init(HTTPClient.maxSpeed) {
            didSet { updateHTTPMaxSpeed() }
        }

        @Published var leftOptionIsAlt: Bool = Wine.leftOptionIsAlt {
            didSet { Wine.leftOptionIsAlt = leftOptionIsAlt }
        }

        @Published var rightOptionIsAlt: Bool = Wine.rightOptionIsAlt {
            didSet { Wine.rightOptionIsAlt = rightOptionIsAlt }
        }

        @Published var leftCommandIsCtrl: Bool = Wine.leftCommandIsCtrl {
            didSet { Wine.leftCommandIsCtrl = leftCommandIsCtrl }
        }

        @Published var rightCommandIsCtrl: Bool = Wine.rightCommandIsCtrl {
            didSet { Wine.rightCommandIsCtrl = rightCommandIsCtrl }
        }

        @Published var preserveNewerSettings = true
        @Published var backupOperationInProgress = false
        @Published var backupStatus = ""
        @Published var backupAlertTitle = ""
        @Published var backupAlertMessage = ""
        @Published var showingBackupAlert = false

        func exportConfigBackup() {
            guard ensureGameIsStopped() else { return }

            let panel = NSSavePanel()
            panel.title = "사용자 설정 내보내기"
            panel.prompt = "내보내기"
            panel.nameFieldStringValue = "FFXIVconf.fea"
            panel.allowedContentTypes = [Self.feaContentType]
            panel.canCreateDirectories = true
            guard panel.runModal() == .OK, let destination = panel.url else {
                return
            }

            startBackupOperation(status: "사용자 설정을 내보내는 중…")
            let configDirectory = Settings.gameConfigPath
            DispatchQueue.global(qos: .utility).async {
                let outcome: Result<ConfigBackupResult, Error> = Result {
                    try KoreanConfigBackup.exportBackup(
                        configDirectory: configDirectory,
                        destination: destination)
                }
                DispatchQueue.main.async {
                    self.finishExport(outcome, destination: destination)
                }
            }
        }

        func importConfigBackup() {
            guard ensureGameIsStopped() else { return }

            let panel = NSOpenPanel()
            panel.title = "사용자 설정 가져오기"
            panel.prompt = "선택"
            panel.allowedContentTypes = [Self.feaContentType]
            panel.allowsMultipleSelection = false
            panel.canChooseDirectories = false
            panel.canChooseFiles = true
            guard panel.runModal() == .OK, let source = panel.url else {
                return
            }

            let confirmation = NSAlert()
            confirmation.alertStyle = .warning
            confirmation.messageText = "사용자 설정을 가져올까요?"
            confirmation.informativeText = preserveNewerSettings
                ? "백업에 포함된 캐릭터 설정을 복원합니다. 백업보다 새로운 로컬 파일은 유지됩니다. 게임이 완전히 종료되어 있어야 합니다."
                : "백업에 포함된 캐릭터 설정으로 로컬 파일을 덮어씁니다. 게임이 완전히 종료되어 있어야 합니다."
            confirmation.addButton(withTitle: "가져오기")
            confirmation.addButton(withTitle: "취소")
            guard confirmation.runModal() == .alertFirstButtonReturn else {
                return
            }
            guard ensureGameIsStopped() else { return }

            startBackupOperation(status: "사용자 설정을 가져오는 중…")
            let configDirectory = Settings.gameConfigPath
            let preserveNewerFiles = preserveNewerSettings
            DispatchQueue.global(qos: .utility).async {
                let outcome: Result<ConfigBackupResult, Error> = Result {
                    try KoreanConfigBackup.importBackup(
                        configDirectory: configDirectory,
                        source: source,
                        preserveNewerFiles: preserveNewerFiles)
                }
                DispatchQueue.main.async {
                    self.finishImport(outcome)
                }
            }
        }

        private static var feaContentType: UTType {
            UTType(filenameExtension: "fea") ?? .data
        }

        private func ensureGameIsStopped() -> Bool {
            guard !FFXIVApp.running else {
                showBackupAlert(
                    title: "게임을 먼저 종료해 주세요",
                    message: "설정 파일이 손상되지 않도록 파이널판타지14를 완전히 종료한 뒤 다시 시도해 주세요.")
                return false
            }
            return true
        }

        private func startBackupOperation(status: String) {
            backupOperationInProgress = true
            backupStatus = status
        }

        private func finishExport(
            _ outcome: Result<ConfigBackupResult, Error>,
            destination: URL
        ) {
            backupOperationInProgress = false
            switch outcome {
            case .success(let result):
                backupStatus = "캐릭터 \(result.characterCount)개, 설정 파일 \(result.fileCount)개를 내보냈습니다."
                showBackupAlert(
                    title: "내보내기 완료",
                    message: "\(backupStatus)\n\n\(destination.path)")
            case .failure(let error):
                backupStatus = "내보내기에 실패했습니다."
                showBackupAlert(
                    title: "내보내기 실패",
                    message: error.localizedDescription)
            }
        }

        private func finishImport(
            _ outcome: Result<ConfigBackupResult, Error>
        ) {
            backupOperationInProgress = false
            switch outcome {
            case .success(let result):
                let skipped =
                    result.skippedFileCount > 0
                    ? " 더 새로운 로컬 파일 \(result.skippedFileCount)개는 유지했습니다."
                    : ""
                backupStatus = "캐릭터 \(result.characterCount)개, 설정 파일 \(result.fileCount)개를 확인했습니다.\(skipped)"
                showBackupAlert(
                    title: "가져오기 완료",
                    message: "\(backupStatus)\n\n다음 게임 실행부터 복원된 설정이 적용됩니다.")
            case .failure(let error):
                backupStatus = "가져오기에 실패했습니다."
                showBackupAlert(
                    title: "가져오기 실패",
                    message: error.localizedDescription)
            }
        }

        private func showBackupAlert(title: String, message: String) {
            backupAlertTitle = title
            backupAlertMessage = message
            showingBackupAlert = true
        }

        private func updateHTTPMaxSpeed() {
            HTTPClient.maxSpeed =
                limitDownloadEnabled ? Double(limitDownloadSpeed) ?? 0.0 : 0.0
        }
    }
}
