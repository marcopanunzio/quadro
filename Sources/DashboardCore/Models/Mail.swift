import Foundation

public struct MailAccountUnread: Hashable, Sendable {
    public var accountName: String
    public var unreadCount: Int

    public init(accountName: String, unreadCount: Int) {
        self.accountName = accountName
        self.unreadCount = unreadCount
    }
}

public struct MailSummary: Hashable, Sendable {
    public var accounts: [MailAccountUnread]
    public var fetchedAt: Date

    public init(accounts: [MailAccountUnread], fetchedAt: Date) {
        self.accounts = accounts
        self.fetchedAt = fetchedAt
    }

    public var totalUnread: Int { accounts.reduce(0) { $0 + $1.unreadCount } }
}
