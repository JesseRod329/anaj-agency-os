import Foundation
import SwiftUI

@Observable
class CloudKitManager {
    var accountStatus: AccountStatus = .couldNotDetermine
    var userName: String?
    var error: String?

    enum AccountStatus: Sendable {
        case available, noAccount, restricted, couldNotDetermine, unavailable
    }

    init() {
        // Keep init side-effect free so SettingsView cannot crash on launch.
    }

    func checkAccountStatus() {
        self.accountStatus = .unavailable
        self.userName = "Local Workspace"
        self.error = "Cloud sync is disabled in this build."
    }
    
    var statusText: String {
        switch accountStatus {
        case .available: return "Active & Syncing"
        case .noAccount: return "Not Signed In"
        case .restricted: return "Restricted"
        case .couldNotDetermine: return "Checking..."
        case .unavailable: return "Unavailable"
        }
    }
    
    var statusColor: Color {
        switch accountStatus {
        case .available: return .green
        case .noAccount: return .gray // Changed from red to be less alarming
        case .restricted: return .orange
        case .couldNotDetermine: return .gray
        case .unavailable: return .red
        }
    }
    
    var statusIcon: String {
        switch accountStatus {
        case .available: return "icloud.fill"
        case .noAccount: return "icloud.slash.fill"
        case .restricted: return "exclamationmark.icloud.fill"
        case .couldNotDetermine: return "icloud"
        case .unavailable: return "exclamationmark.icloud"
        }
    }
}
