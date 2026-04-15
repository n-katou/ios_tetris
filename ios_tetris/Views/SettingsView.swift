import SwiftUI

struct SettingsView: View {
    @Environment(\.dismiss) private var dismiss

    @State private var bgmEnabled:     Bool = AppSettings.shared.bgmEnabled
    @State private var sfxEnabled:     Bool = AppSettings.shared.sfxEnabled
    @State private var hapticsEnabled: Bool = AppSettings.shared.hapticsEnabled
    @State private var ghostEnabled:   Bool = AppSettings.shared.ghostEnabled

    var body: some View {
        NavigationStack {
            ZStack {
                Color.black.ignoresSafeArea()

                List {
                    Section {
                        SettingsToggle(label: "BGM", icon: "music.note", color: .cyan,
                                       isOn: $bgmEnabled)
                        SettingsToggle(label: "効果音", icon: "speaker.wave.2", color: .blue,
                                       isOn: $sfxEnabled)
                        SettingsToggle(label: "バイブ（触覚）", icon: "iphone.radiowaves.left.and.right",
                                       color: .purple, isOn: $hapticsEnabled)
                    } header: {
                        Text("サウンド & フィードバック")
                            .foregroundColor(.gray)
                    }
                    .listRowBackground(Color.white.opacity(0.07))

                    Section {
                        SettingsToggle(label: "ゴーストピース", icon: "square.dashed", color: .orange,
                                       isOn: $ghostEnabled)
                    } header: {
                        Text("表示")
                            .foregroundColor(.gray)
                    }
                    .listRowBackground(Color.white.opacity(0.07))
                }
                .scrollContentBackground(.hidden)
            }
            .navigationTitle("設定")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("完了") { dismiss() }
                        .foregroundColor(.cyan)
                }
            }
            .preferredColorScheme(.dark)
        }
        .onChange(of: bgmEnabled)     { v in
            AppSettings.shared.bgmEnabled = v
            if v { BGMPlayer.shared.play() } else { BGMPlayer.shared.stop() }
        }
        .onChange(of: sfxEnabled)     { v in AppSettings.shared.sfxEnabled     = v }
        .onChange(of: hapticsEnabled) { v in AppSettings.shared.hapticsEnabled = v }
        .onChange(of: ghostEnabled)   { v in AppSettings.shared.ghostEnabled   = v }
    }
}

// MARK: - Row

private struct SettingsToggle: View {
    let label:  String
    let icon:   String
    let color:  Color
    @Binding var isOn: Bool

    var body: some View {
        Toggle(isOn: $isOn) {
            HStack(spacing: 12) {
                ZStack {
                    RoundedRectangle(cornerRadius: 8)
                        .fill(color.opacity(0.2))
                        .frame(width: 32, height: 32)
                    Image(systemName: icon)
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundStyle(color)
                }
                Text(label)
                    .foregroundColor(.white)
            }
        }
        .tint(.cyan)
    }
}
