import SwiftUI
import MagnificatDesktopCore

/// The whole window. Renders only what `AppViewModel` exposes — no decision
/// logic lives here. `DESKTOP-SPEC.md` §6 is the contract this must satisfy:
///
/// - No modal dialog, alert, sheet, or confirmation anywhere — a blocked
///   command queue has no way to recover for the automation agent driving
///   this. Errors are plain text in the status area and in the log, nothing
///   the operator has to dismiss.
/// - No file picker, no drag-and-drop target — the folder is set by typing
///   into the text field below and clicking "Use this folder".
/// - The status area and file list never require scrolling: `visibleFileLines`
///   / `idleVisibleLines` are already capped at 6 entries by MagnificatDesktopCore.
struct ContentView: View {
    @ObservedObject var viewModel: AppViewModel
    @State private var folderFieldText: String = ""

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            statusArea
            fileList
            folderControl
            runButton
        }
        .padding(20)
        .frame(minWidth: 520, idealWidth: 560, minHeight: 460)
        .onAppear { folderFieldText = viewModel.folderText }
        .onChange(of: viewModel.folderText) { newValue in folderFieldText = newValue }
    }

    // MARK: - Status area
    //
    // All of the actual composition — what to show while running, what to show
    // once a run has happened versus before one ever has — lives in
    // AppViewModel.display*, tested there. A first version composed this
    // directly from viewModel.runResult / .scanned here, untested, and a real
    // run surfaced a bug in it: "DONE" showed the idle folder listing
    // underneath because Run leaves input files in place and rescans
    // afterward. This view now only reads the already-correct result.

    /// High-contrast, unmistakable at a glance — this is the one thing an
    /// operator (human or agent) needs to read correctly from across the room
    /// or from a screenshot. `DESKTOP-SPEC.md` §6.
    private var statusColor: Color {
        if viewModel.isRunning { return .yellow }
        switch viewModel.runResult?.status {
        case .failed: return .red
        case .done: return .green
        default: return .gray
        }
    }

    private var statusArea: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(viewModel.displayHeadline)
                .font(.system(size: 40, weight: .heavy, design: .rounded))
                .foregroundStyle(.black)
            if let outputFilename = viewModel.displayOutputFilename {
                Text(outputFilename)
                    .font(.title2.weight(.semibold))
                    .foregroundStyle(.black)
            }
            if let detail = viewModel.displayDetail {
                Text(detail)
                    .font(.title3)
                    .foregroundStyle(.black.opacity(0.8))
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(20)
        .background(statusColor)
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }

    // MARK: - File list — never scrolls; both sides are pre-capped at 6 lines.

    private var fileList: some View {
        VStack(alignment: .leading, spacing: 4) {
            ForEach(viewModel.displayFileLines, id: \.self) { line in
                Text(line)
                    .font(.system(.body, design: .monospaced))
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    // MARK: - Folder control — a plain text field, never a picker.

    private var folderControl: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("Folder").font(.caption).foregroundStyle(.secondary)
            HStack {
                TextField("Folder path", text: $folderFieldText)
                    .textFieldStyle(.roundedBorder)
                    .disableAutocorrection(true)
                Button("Use this folder") {
                    viewModel.useFolder(folderFieldText)
                }
                .disabled(viewModel.isRunning)
            }
            if let error = viewModel.folderErrorMessage {
                Text(error)
                    .font(.callout)
                    .foregroundStyle(.red)
            }
        }
    }

    // MARK: - Run

    private var runButton: some View {
        Button {
            Task { await viewModel.run() }
        } label: {
            Text("Run")
                .font(.title2.weight(.semibold))
                .frame(maxWidth: .infinity)
                .padding(.vertical, 8)
        }
        .buttonStyle(.borderedProminent)
        .disabled(!viewModel.canRun)
    }
}
