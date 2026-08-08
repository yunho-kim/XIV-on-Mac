//
//  SettingsGeneralTabView.swift
//  XIV on Mac
//
//  Created by Chris Backas on 1/14/23.
//

import SeeURL  // HTTPClient/Download speed limiter setting
import SwiftUI

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

        private func updateHTTPMaxSpeed() {
            HTTPClient.maxSpeed =
                limitDownloadEnabled ? Double(limitDownloadSpeed) ?? 0.0 : 0.0
        }
    }
}
