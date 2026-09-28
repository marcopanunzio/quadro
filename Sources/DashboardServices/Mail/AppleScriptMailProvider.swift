import AppKit
import DashboardCore
import Foundation

/// Errori del provider mail via AppleScript.
public enum MailError: Error, Sendable {
    /// Permesso di Automazione verso Mail negato dall'utente (errore AppleScript -1743).
    case notAuthorized
    case scriptFailed(String)
}

/// Legge il numero di mail non lette per account tramite AppleScript, in sola lettura (REQ-042).
/// Mail.app non viene mai avviata da questo provider: se non è già in esecuzione, `unreadSummary()`
/// restituisce `nil` senza eseguire alcuno script.
public final class AppleScriptMailProvider: MailProvider, @unchecked Sendable {
    private static let bundleIdentifier = "com.apple.mail"
    private static let notAuthorizedErrorCode = -1743

    private let queue = DispatchQueue(label: "com.mpanunzio.quadro.mail.applescript")

    public init() {}

    public func unreadSummary() async throws -> MailSummary? {
        guard !NSRunningApplication.runningApplications(withBundleIdentifier: Self.bundleIdentifier).isEmpty else {
            return nil
        }

        let output = try await runScript()
        return MailSummary(accounts: Self.parse(output), fetchedAt: Date())
    }

    private func runScript() async throws -> String {
        try await withCheckedThrowingContinuation { continuation in
            self.queue.async {
                guard let script = NSAppleScript(source: MailScript.source) else {
                    continuation.resume(throwing: MailError.scriptFailed("impossibile compilare lo script"))
                    return
                }

                var errorInfo: NSDictionary?
                let result = script.executeAndReturnError(&errorInfo)

                if let errorInfo {
                    let code = (errorInfo[NSAppleScript.errorNumber] as? Int) ?? 0
                    let message = (errorInfo[NSAppleScript.errorMessage] as? String) ?? "errore sconosciuto"
                    if code == Self.notAuthorizedErrorCode {
                        continuation.resume(throwing: MailError.notAuthorized)
                    } else {
                        continuation.resume(throwing: MailError.scriptFailed(message))
                    }
                    return
                }

                continuation.resume(returning: result.stringValue ?? "")
            }
        }
    }

    /// Parser puro dell'output dello script: una riga per account, `nome<TAB>conteggio`.
    /// Righe vuote ignorate, conteggi non numerici scartati; se il nome contiene dei tab
    /// si considera l'ultimo campo come conteggio e il resto come nome.
    public static func parse(_ output: String) -> [MailAccountUnread] {
        let normalized = output.replacingOccurrences(of: "\r\n", with: "\n")
        var results: [MailAccountUnread] = []

        for rawLine in normalized.split(separator: "\n", omittingEmptySubsequences: true) {
            let line = String(rawLine)
            guard !line.trimmingCharacters(in: .whitespaces).isEmpty else { continue }

            var fields = line.components(separatedBy: "\t")
            guard fields.count >= 2 else { continue }

            let countField = fields.removeLast()
            guard let count = Int(countField.trimmingCharacters(in: .whitespaces)) else { continue }

            let name = fields.joined(separator: "\t")
            guard !name.isEmpty else { continue }

            results.append(MailAccountUnread(accountName: name, unreadCount: count))
        }

        return results
    }
}
