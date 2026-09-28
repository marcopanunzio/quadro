import DashboardCore
import DashboardServices
import Testing

@Suite struct MailParsingTests {
    @Test func parsesNormalOutput() {
        let output = "Lavoro\t3\niCloud\t0\n"
        let accounts = AppleScriptMailProvider.parse(output)
        #expect(accounts == [
            MailAccountUnread(accountName: "Lavoro", unreadCount: 3),
            MailAccountUnread(accountName: "iCloud", unreadCount: 0),
        ])
    }

    @Test func ignoresEmptyLines() {
        let output = "Lavoro\t3\n\n\niCloud\t0\n"
        let accounts = AppleScriptMailProvider.parse(output)
        #expect(accounts == [
            MailAccountUnread(accountName: "Lavoro", unreadCount: 3),
            MailAccountUnread(accountName: "iCloud", unreadCount: 0),
        ])
    }

    @Test func discardsNonNumericCounts() {
        let output = "Lavoro\t3\niCloud\tn/d\nAltro\t5\n"
        let accounts = AppleScriptMailProvider.parse(output)
        #expect(accounts == [
            MailAccountUnread(accountName: "Lavoro", unreadCount: 3),
            MailAccountUnread(accountName: "Altro", unreadCount: 5),
        ])
    }

    @Test func accountNameWithTabTakesLastFieldAsCount() {
        let output = "Casa\tPersonale\t7\n"
        let accounts = AppleScriptMailProvider.parse(output)
        #expect(accounts == [
            MailAccountUnread(accountName: "Casa\tPersonale", unreadCount: 7),
        ])
    }

    @Test func handlesNamesWithSpacesAndAccents() {
        let output = "Posta università\t2\n"
        let accounts = AppleScriptMailProvider.parse(output)
        #expect(accounts == [
            MailAccountUnread(accountName: "Posta università", unreadCount: 2),
        ])
    }

    @Test func handlesCarriageReturnLineEndings() {
        let output = "Lavoro\t3\r\niCloud\t1\r\n"
        let accounts = AppleScriptMailProvider.parse(output)
        #expect(accounts == [
            MailAccountUnread(accountName: "Lavoro", unreadCount: 3),
            MailAccountUnread(accountName: "iCloud", unreadCount: 1),
        ])
    }

    @Test func emptyOutputYieldsNoAccounts() {
        #expect(AppleScriptMailProvider.parse("").isEmpty)
    }
}
