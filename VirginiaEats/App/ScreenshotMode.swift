import Foundation
import CoreLocation
import UIKit

/// `-screenshot <name>` opens one screen with fixed state for App Store screenshots (scripts/capture-screenshots.sh).
/// Names: home, hams, oysters, counters, latin, asian, stew, wine, honors, oldest, detail, map, saved, about.
enum ScreenshotMode {
    /// Debug builds only: an App Store build ignores the launch argument, so no one can reach seeded screens or fake locations.
    static var name: String? {
        #if DEBUG
        let args = ProcessInfo.processInfo.arguments
        guard let i = args.firstIndex(of: "-screenshot"), i + 1 < args.count else { return nil }
        return args[i + 1]
        #else
        return nil
        #endif
    }
    static var isActive: Bool { name != nil }

    @MainActor
    static func apply(to model: AppModel) {
        guard let name, model.isLoaded else { return }
        model.filters = Filters()
        // downtown Richmond (Capitol Square), so "nearest" lists have distances without a permission prompt
        model.screenshotLocation = CLLocation(latitude: 37.5385, longitude: -77.4336)
        // by name and town, ignoring case, so a rebuild with a slightly different casing still finds the place; the hand-checked one first
        let pick = { (n: String, town: String?) -> Place? in
            let hits = model.places.filter { $0.name.caseInsensitiveCompare(n) == .orderedSame && (town == nil || $0.city == town) }
            return hits.first(where: \.handChecked) ?? hits.first
        }
        for p in [pick("Sally Bell's Kitchen", "Richmond"), pick("Texas Tavern", "Roanoke"), pick("Hank's Oyster Bar", "Alexandria")]
            .compactMap({ $0 }) where !model.isSaved(p) {
            model.toggleSaved(p)
        }
        let open = { (g: Guide) in model.tab = .guides; model.selectedGuide = g; model.guidesPath = [.guide(g)] }
        switch name {
        case "hams": open(.hams)
        case "oysters":
            // Norfolk, among the Hampton Roads raw bars
            model.screenshotLocation = CLLocation(latitude: 36.8508, longitude: -76.2859)
            open(.oysters)
        case "counters": open(.counters)
        case "latin", "asian":
            // Falls Church (Seven Corners), between the Eden Center and Annandale
            model.screenshotLocation = CLLocation(latitude: 38.8730, longitude: -77.1530)
            open(name == "latin" ? .latin : .asian)
        case "stew": open(.stew)
        case "wine":
            // Middleburg, in hunt country
            model.screenshotLocation = CLLocation(latitude: 38.9690, longitude: -77.7355)
            open(.wine)
        case "honors": open(.honors)
        case "oldest": open(.oldest)
        case "detail":
            // Texas Tavern: a classic counter with its 1930 founding year and its note
            open(.counters)
            if let p = pick("Texas Tavern", "Roanoke") ?? model.places.first {
                model.selectedPlace = p; model.guidesPath.append(.place(p))
            }
        case "map": model.tab = .map
        case "saved": model.tab = .saved
        case "about": model.tab = .about
        default: model.tab = .guides; model.selectedGuide = nil
        }
        // iPad shows the place column next to every list, so give each shot a place instead of "Pick a place": a different
        // honored or hand-checked one per shot.
        guard UIDevice.current.userInterfaceIdiom == .pad, model.selectedPlace == nil else { return }
        let place: Place? = switch name {
        case "home": pick("Sally Bell's Kitchen", "Richmond")
        case "hams": pick("Virginia Diner", "Wakefield")
        case "oysters": pick("Chick's Oyster Bar", "Virginia Beach")
        case "counters": pick("Texas Tavern", "Roanoke")
        case "latin": pick("Peru 703", "Chantilly")
        case "asian": pick("Banh Mi So 1", "Falls Church")
        case "wine": pick("Red Fox Inn & Tavern", "Middleburg")
        case "map": pick("Sally Bell's Kitchen", "Richmond")
        case "honors": pick("The Inn at Little Washington", "Washington")
        case "oldest": pick("Red Fox Inn & Tavern", "Middleburg")
        case "saved": pick("Texas Tavern", "Roanoke")
        case "about": nil
        default: pick("Texas Tavern", "Roanoke")
        }
        model.selectedPlace = place
    }
}
