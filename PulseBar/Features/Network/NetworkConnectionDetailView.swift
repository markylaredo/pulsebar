import SwiftUI

struct NetworkConnectionDetailView: View {
    let connection: NetworkConnectionSnapshot
    let onClose: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 9) {
                Image(nsImage: ProcessIconCache.shared.icon(
                    for: connection.processIdentity,
                    processID: connection.pid,
                    executablePath: connection.executablePath
                ))
                .resizable()
                .scaledToFit()
                .frame(width: 24, height: 24)
                .accessibilityHidden(true)
                VStack(alignment: .leading, spacing: 1) {
                    Text(connection.processName)
                        .font(.headline)
                        .lineLimit(1)
                    Text("PID \(connection.pid) · \(connection.protocolName) · \(connection.stateName)")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                Spacer()
                Button(action: onClose) {
                    Image(systemName: "xmark")
                }
                .buttonStyle(.plain)
                .foregroundStyle(.secondary)
                .help("Close connection details")
                .accessibilityLabel("Close connection details")
            }

            HStack(alignment: .top, spacing: 20) {
                detail(label: "LOCAL", value: connection.localDisplayName)
                Image(systemName: "arrow.right")
                    .foregroundStyle(.tertiary)
                    .padding(.top, 17)
                    .accessibilityHidden(true)
                detail(label: "REMOTE", value: connection.remoteDisplayName)
                detail(label: "INTERFACE", value: connection.interfaceName ?? "Unavailable")
                if let path = connection.executablePath {
                    detail(label: "EXECUTABLE", value: path)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
            }
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 12)
        .background(.bar)
    }

    private func detail(label: String, value: String) -> some View {
        VStack(alignment: .leading, spacing: 3) {
            Text(label)
                .font(.caption2.weight(.semibold))
                .foregroundStyle(.secondary)
            Text(value)
                .font(.caption.monospaced())
                .lineLimit(2)
                .truncationMode(.middle)
                .textSelection(.enabled)
        }
        .accessibilityElement(children: .combine)
    }
}
