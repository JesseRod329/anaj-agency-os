import Foundation
import EventKit
import Observation
import Combine

@Observable
final class CalendarManager {
    private let eventStore = EKEventStore()
    var events: [EKEvent] = []
    var isAuthorized = false
    private var cancellables = Set<AnyCancellable>()
    
    init() {
        // Don't request access immediately to avoid entitlement crashes/prompts on startup
        // Listen for external changes (e.g. Calendar app updates)
        NotificationCenter.default.publisher(for: .EKEventStoreChanged, object: eventStore)
            .sink { [weak self] _ in
                self?.fetchEvents()
            }
            .store(in: &cancellables)
    }
    
    func checkAuthorization() {
        let status = EKEventStore.authorizationStatus(for: .event)
        switch status {
        case .authorized, .fullAccess:
            isAuthorized = true
            fetchEvents()
        case .notDetermined:
            requestAccess()
        default:
            isAuthorized = false
        }
    }
    
    func requestAccess() {
        if #available(macOS 14.0, iOS 17.0, *) {
            eventStore.requestFullAccessToEvents { [weak self] granted, error in
                DispatchQueue.main.async {
                    self?.isAuthorized = granted
                    if granted { self?.fetchEvents() }
                }
            }
        } else {
            eventStore.requestAccess(to: .event) { [weak self] granted, error in
                DispatchQueue.main.async {
                    self?.isAuthorized = granted
                    if granted { self?.fetchEvents() }
                }
            }
        }
    }
    
    func fetchEvents() {
        guard isAuthorized else { return }
        
        let calendar = Calendar.current
        // Fetch 1 year window (6 months back, 6 months forward)
        let startDate = calendar.date(byAdding: .month, value: -6, to: Date()) ?? Date()
        let endDate = calendar.date(byAdding: .month, value: 6, to: Date()) ?? Date()
        
        let predicate = eventStore.predicateForEvents(withStart: startDate, end: endDate, calendars: nil)
        
        // Run on background thread
        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            guard let self = self else { return }
            let foundEvents = self.eventStore.events(matching: predicate)
            let sortedEvents = foundEvents.sorted { $0.startDate < $1.startDate }
            
            DispatchQueue.main.async {
                self.events = sortedEvents
            }
        }
    }
}
