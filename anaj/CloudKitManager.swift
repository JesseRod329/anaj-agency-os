import Foundation
import SwiftUI
import CloudKit

@Observable
class CloudKitManager {
    var accountStatus: AccountStatus = .couldNotDetermine
    var userName: String?
    var error: String?

    enum AccountStatus: Sendable {
        case available, noAccount, restricted, couldNotDetermine, unavailable
    }

    init() {
        // Ensure init does absolutely nothing related to CloudKit
    }

    func checkAccountStatus() {
        // Disable CloudKit on iOS Simulator - it crashes without entitlements
        #if targetEnvironment(simulator) && os(iOS)
        self.accountStatus = .unavailable
        self.error = "CloudKit not available in iOS Simulator"
        return
        #endif

        // Keep CloudKit disabled until iCloud entitlements/profile are stable.
        self.accountStatus = .noAccount
        self.error = "CloudKit is currently disabled for local builds."
    }

    private func fetchUserIdentity() {
        #if !DEBUG
        Task {
            do {
                let container = CKContainer.default()
                let userId = try await container.userRecordID()
                let info: CKUserIdentity = try await withCheckedThrowingContinuation { continuation in
                    container.discoverUserIdentity(withUserRecordID: userId) { identity, error in
                        if let error = error {
                            continuation.resume(throwing: error)
                        } else if let identity = identity {
                            continuation.resume(returning: identity)
                        } else {
                            continuation.resume(throwing: CKError(.unknownItem))
                        }
                    }
                }
                
                await MainActor.run {
                    if let components = info.nameComponents {
                        self.userName = PersonNameComponentsFormatter().string(from: components)
                    } else {
                        self.userName = "iCloud User"
                    }
                }
            } catch {
                print("Failed to fetch user identity: \(error.localizedDescription)")
            }
        }
        #endif
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
