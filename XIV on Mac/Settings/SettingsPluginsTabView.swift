//
//  SettingsPluginsTabView.swift
//  XIV on Mac KR
//

import SwiftUI
import XIVLauncher

struct SettingsPluginsTabView: View {
    @StateObject private var viewModel = ViewModel()

    var body: some View {
        VStack {
            Text("SETTINGS_PLUGINS_WHAT_IS_DALAMUD_BLURB")
                .multilineTextAlignment(.leading)
                .lineLimit(nil)
                .padding([.top, .leading, .trailing])
                .frame(maxWidth: .infinity, alignment: .leading)

            HStack {
                Toggle(isOn: $viewModel.dalamudEnabled) {
                    Text("SETTINGS_PLUGINS_DALAMUD_ENABLE")
                }
                .padding(.leading)
                Spacer()
                Toggle(isOn: $viewModel.dalamudEntryPoint) {
                    Text("SETTINGS_PLUGINS_DALAMUD_ENTRYPOINT")
                }
                .disabled(!viewModel.dalamudEnabled)
                Spacer()
            }

            HStack {
                Toggle(isOn: $viewModel.dalamudSafeMode) {
                    Text("안전 모드 (플러그인 없이 시작)")
                }
                .padding(.leading)
                .disabled(!viewModel.dalamudEnabled)
                Spacer()
            }

            Text("처음에는 안전 모드로 실행해 한국 전용 Dalamud 주입을 확인하세요. 정상 동작을 확인한 뒤 이 옵션을 끄면 플러그인이 활성화됩니다.")
                .font(.footnote)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.leading)
                .padding(.horizontal)
                .frame(maxWidth: .infinity, alignment: .leading)

            if !viewModel.dalamudEntryPoint {
                Text("SETTINGS_PLUGINS_DALAMUD_DELAY_BLURB")
                    .multilineTextAlignment(.leading)
                    .lineLimit(nil)
                    .padding([.top, .leading, .trailing])
                    .frame(maxWidth: .infinity, alignment: .leading)

                HStack {
                    Text("SETTINGS_PLUGINS_DALAMUD_DELAY_LABEL")
                        .padding(.leading)
                    TextField("0", text: $viewModel.dalamudDelay)
                        .frame(minWidth: 50)
                        .fixedSize(horizontal: true, vertical: false)
                    Text("SETTINGS_PLUGINS_DALAMUD_DELAY_UNITS")
                    Spacer()
                }
            }

            Divider().padding(.top)

            VStack(alignment: .leading, spacing: 8) {
                Text("한국 전용 Dalamud 배포 채널")
                    .font(.headline)
                Text("dal4kr/Dalamud.Updater와 같은 한국 전용 매니페스트를 사용합니다. 앱 시작 시 최신 빌드와 필요한 .NET 런타임·자산을 자동으로 내려받고 무결성을 확인합니다.")
                    .font(.footnote)
                    .foregroundColor(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
                Button("지금 업데이트 확인") {
                    updateDalamud("", "")
                }
                .disabled(!viewModel.dalamudEnabled)
            }
            .padding(.horizontal)
            .frame(maxWidth: .infinity, alignment: .leading)

            Divider().padding(.top)

            Text("SETTINGS_PLUGINS_DISCORD_BLURB")
                .multilineTextAlignment(.leading)
                .lineLimit(nil)
                .padding([.top, .leading, .trailing])
                .frame(maxWidth: .infinity, alignment: .leading)

            HStack {
                Toggle(isOn: $viewModel.discordBridge) {
                    Text("SETTINGS_PLUGINS_DISCORD_TOGGLE")
                }
                .padding(.leading)
                Spacer()
            }
            Spacer()
        }
    }
}

struct SettingsPluginsTabView_Previews: PreviewProvider {
    static var previews: some View {
        SettingsPluginsTabView()
    }
}

extension SettingsPluginsTabView {
    @MainActor class ViewModel: ObservableObject {
        @Published var dalamudEnabled: Bool = Settings.dalamudEnabled {
            didSet { Settings.dalamudEnabled = dalamudEnabled }
        }

        @Published var dalamudEntryPoint: Bool = Settings.dalamudEntryPoint {
            didSet { Settings.dalamudEntryPoint = dalamudEntryPoint }
        }

        @Published var dalamudSafeMode: Bool = Settings.dalamudSafeMode {
            didSet { Settings.dalamudSafeMode = dalamudSafeMode }
        }

        @Published var dalamudDelay: String = .init(Settings.injectionDelay) {
            didSet { Settings.injectionDelay = Double(dalamudDelay) ?? 0 }
        }

        @Published var discordBridge: Bool = DiscordBridge.enabled {
            didSet { DiscordBridge.enabled = discordBridge }
        }
    }
}
