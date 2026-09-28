import Foundation

/// Sorgente AppleScript per il conteggio delle mail non lette (sola lettura, REQ-042).
/// Somma lo "unread count" delle caselle in arrivo di ogni account abilitato: il nome
/// della casella varia per tipo di account (iCloud "INBOX", Exchange/Gmail "Inbox",
/// localizzato "Posta in arrivo"), quindi si cerca per nome tra le mailbox dell'account.
enum MailScript {
    static let source = """
    set output to ""
    tell application "Mail"
        set inboxNames to {"INBOX", "Inbox", "Posta in arrivo"}
        repeat with acct in (every account whose enabled is true)
            set acctName to name of acct
            set totalUnread to 0
            try
                repeat with mb in (mailboxes of acct)
                    if inboxNames contains (name of mb) then
                        set totalUnread to totalUnread + (unread count of mb)
                    end if
                end repeat
            end try
            set output to output & acctName & tab & (totalUnread as string) & linefeed
        end repeat
    end tell
    return output
    """
}
