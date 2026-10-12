//
//  SharedLocation.swift
//  Salat
//
//  The app owns the device location. It saves the last one here (in the App Group
//  shared with the widget extension) so widgets never have to ask for location.
//

import Foundation

struct SharedLocation: Codable, Equatable {
    var latitude: Double
    var longitude: Double
    /// "City, State CC" as shown at the top of the app, when known
    var name: String?
    var updatedAt: Date
}

enum SharedLocationStore {
    static let groupIdentifier = "group.com.psaray.salat"
    private static let key = "lastKnownLocation"

    /// False when this process was not signed with the App Group, e.g. the capability is
    /// missing or the provisioning profile does not include it
    static var isGroupAvailable: Bool {
        FileManager.default.containerURL(forSecurityApplicationGroupIdentifier: groupIdentifier) != nil
    }

    static func load(from defaults: UserDefaults? = UserDefaults(suiteName: SharedLocationStore.groupIdentifier)) -> SharedLocation? {
        guard let data = defaults?.data(forKey: key) else { return nil }
        return try? JSONDecoder().decode(SharedLocation.self, from: data)
    }

    @discardableResult
    static func save(_ location: SharedLocation, to defaults: UserDefaults? = UserDefaults(suiteName: SharedLocationStore.groupIdentifier)) -> Bool {
        guard let defaults = defaults, let data = try? JSONEncoder().encode(location) else { return false }
        defaults.set(data, forKey: key)
        return true
    }
}
