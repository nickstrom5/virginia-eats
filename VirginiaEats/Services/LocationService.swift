import CoreLocation
import Observation
import UIKit

/// "Near me" sorting. Asks for when-in-use permission only when a list is sorted by distance or "My location" is tapped; the location never leaves the device.
@MainActor
@Observable
final class LocationService: NSObject, CLLocationManagerDelegate {
    private let manager = CLLocationManager()
    private(set) var location: CLLocation?
    private(set) var status: CLAuthorizationStatus = .notDetermined
    /// no fix within 12 seconds, or Core Location reported an error
    private(set) var failed = false
    private var timeout: Task<Void, Never>?
    /// when the current request started: a fix from before it is a cached one (from launch, or before a drive) and doesn't count
    private var askedAt = Date.distantPast

    override init() {
        super.init()
        manager.delegate = self
        manager.desiredAccuracy = kCLLocationAccuracyHundredMeters
        status = manager.authorizationStatus
    }

    var isDenied: Bool { status == .denied || status == .restricted }

    /// Every place is in Virginia, so a reader elsewhere (an App Reviewer in California, say) gets told rather than an empty map.
    /// A coarse outline of the state (Idaho's lesson: a bounding box would count D.C., Bristol, Tennessee and Bluefield, West Virginia),
    /// drawn a little outside the line so the river and bay shores count as inside.
    var isOutsideVirginia: Bool {
        guard let c = location?.coordinate else { return false }
        return !VirginiaOutline.contains(c)
    }

    /// Once location is off for the app, iOS won't ask again; the app's page in Settings is the only way back.
    static func openSettings() {
        if let url = URL(string: UIApplication.openSettingsURLString) { UIApplication.shared.open(url) }
    }

    func request() {
        switch manager.authorizationStatus {
        case .notDetermined: manager.requestWhenInUseAuthorization()
        case .authorizedWhenInUse, .authorizedAlways: locate()
        default: break
        }
    }

    private func locate() {
        failed = false
        let asked = Date()
        askedAt = asked
        manager.requestLocation()
        timeout?.cancel()
        timeout = Task { [weak self] in
            try? await Task.sleep(for: .seconds(12))
            guard let self, !Task.isCancelled else { return }
            if (self.location?.timestamp ?? .distantPast) < asked { self.failed = true }
        }
    }

    nonisolated func locationManagerDidChangeAuthorization(_ m: CLLocationManager) {
        let s = m.authorizationStatus
        Task { @MainActor in
            self.status = s
            if s == .authorizedWhenInUse || s == .authorizedAlways { self.locate() }
        }
    }

    nonisolated func locationManager(_ m: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        guard let l = locations.last else { return }
        Task { @MainActor in
            // "My location" needs a fresh fix on every tap: a cached one from before the request would put you back where you were
            guard l.timestamp >= self.askedAt.addingTimeInterval(-2) else { return }
            self.location = l; self.failed = false; self.timeout?.cancel()
        }
    }

    nonisolated func locationManager(_ m: CLLocationManager, didFailWithError error: Error) {
        Task { @MainActor in if self.location == nil { self.failed = true } }
    }
}

extension CLLocation {
    /// "0.4 mi", "12 mi", "1,012 mi" (an App Reviewer in California is a thousand miles out)
    func milesText(to other: CLLocation) -> String {
        let mi = distance(from: other) / 1609.344
        return (mi < 10 ? mi.formatted(.number.precision(.fractionLength(1))) : Int(mi.rounded()).formatted()) + " mi"
    }
}

/// A coarse Virginia outline (longitude, latitude), about 600 m outside the Overture land outline (buffer 0.006°, simplify 0.01°; five
/// rings: the mainland, the Eastern Shore and the Chesapeake islands). Arlington, Alexandria, Chincoteague, Tangier, Virginia Beach, Bristol
/// and Bluefield, Virginia and Lovettsville are inside; Washington, D.C., Georgetown, Bristol (Tennessee), Bluefield (West Virginia), Harpers
/// Ferry, Eden (North Carolina) and Ocean City (Maryland) are not.
enum VirginiaOutline {
    static let rings: [[(Double, Double)]] = [
        [(-76.031, 37.266), (-76.022, 37.328), (-75.972, 37.396), (-75.989, 37.417), (-75.94, 37.548), (-75.945, 37.571),
         (-75.909, 37.631), (-75.894, 37.613), (-75.883, 37.613), (-75.895, 37.655), (-75.87, 37.674), (-75.852, 37.669),
         (-75.872, 37.683), (-75.855, 37.695), (-75.862, 37.705), (-75.844, 37.706), (-75.833, 37.74), (-75.794, 37.759),
         (-75.818, 37.79), (-75.784, 37.813), (-75.733, 37.792), (-75.743, 37.81), (-75.725, 37.802), (-75.713, 37.85),
         (-75.683, 37.849), (-75.7, 37.896), (-75.762, 37.895), (-75.741, 37.906), (-75.747, 37.918), (-75.714, 37.944),
         (-75.649, 37.942), (-75.654, 37.969), (-75.626, 38.0), (-75.378, 38.021), (-75.372, 38.005), (-75.424, 37.981),
         (-75.431, 37.959), (-75.417, 37.944), (-75.379, 37.944), (-75.279, 38.025), (-75.238, 38.032), (-75.37, 37.851),
         (-75.396, 37.846), (-75.405, 37.877), (-75.357, 37.883), (-75.414, 37.891), (-75.421, 37.866), (-75.452, 37.856),
         (-75.53, 37.779), (-75.608, 37.612), (-75.596, 37.565), (-75.684, 37.475), (-75.68, 37.462), (-75.657, 37.469),
         (-75.654, 37.443), (-75.715, 37.365), (-75.732, 37.367), (-75.735, 37.395), (-75.718, 37.392), (-75.701, 37.418),
         (-75.717, 37.437), (-75.708, 37.448), (-75.731, 37.48), (-75.742, 37.472), (-75.77, 37.492), (-75.813, 37.459),
         (-75.814, 37.424), (-75.791, 37.413), (-75.79, 37.396), (-75.828, 37.381), (-75.851, 37.392), (-75.902, 37.334),
         (-75.905, 37.319), (-75.876, 37.321), (-75.885, 37.332), (-75.854, 37.373), (-75.848, 37.354), (-75.862, 37.34),
         (-75.829, 37.337), (-75.862, 37.305), (-75.851, 37.283), (-75.836, 37.295), (-75.82, 37.279), (-75.867, 37.249),
         (-75.879, 37.213), (-75.861, 37.199), (-75.842, 37.204), (-75.841, 37.242), (-75.809, 37.254), (-75.807, 37.289),
         (-75.79, 37.281), (-75.795, 37.228), (-75.828, 37.17), (-75.892, 37.114), (-75.927, 37.108), (-75.903, 37.145),
         (-75.885, 37.145), (-75.901, 37.169), (-75.917, 37.15), (-75.914, 37.224), (-75.937, 37.179), (-75.92, 37.132),
         (-75.954, 37.114), (-75.935, 37.103), (-75.938, 37.084), (-75.973, 37.078), (-75.987, 37.095), (-75.975, 37.114),
         (-75.983, 37.155), (-76.018, 37.201)],
        [(-75.772, 37.295), (-75.797, 37.307), (-75.763, 37.32), (-75.793, 37.324), (-75.785, 37.343), (-75.755, 37.337),
         (-75.728, 37.352)],
        [(-83.401, 36.682), (-83.311, 36.717), (-83.14, 36.749), (-83.138, 36.787), (-83.075, 36.86), (-83.01, 36.854),
         (-82.884, 36.895), (-82.864, 36.93), (-82.871, 36.983), (-82.729, 37.049), (-82.725, 37.126), (-82.501, 37.232),
         (-82.355, 37.272), (-81.969, 37.544), (-81.921, 37.516), (-81.95, 37.486), (-81.99, 37.475), (-81.93, 37.442),
         (-81.92, 37.363), (-81.856, 37.32), (-81.845, 37.291), (-81.754, 37.281), (-81.736, 37.245), (-81.675, 37.208),
         (-81.558, 37.213), (-81.513, 37.238), (-81.502, 37.263), (-81.423, 37.278), (-81.366, 37.344), (-81.224, 37.242),
         (-81.114, 37.284), (-80.95, 37.302), (-80.86, 37.349), (-80.889, 37.384), (-80.861, 37.435), (-80.781, 37.4),
         (-80.767, 37.379), (-80.554, 37.479), (-80.508, 37.487), (-80.475, 37.429), (-80.304, 37.513), (-80.293, 37.529),
         (-80.336, 37.534), (-80.322, 37.548), (-80.334, 37.568), (-80.23, 37.626), (-80.271, 37.641), (-80.312, 37.693),
         (-80.26, 37.727), (-80.263, 37.759), (-80.166, 37.88), (-80.005, 37.999), (-79.937, 38.104), (-79.951, 38.133),
         (-79.926, 38.157), (-79.925, 38.187), (-79.794, 38.273), (-79.816, 38.309), (-79.768, 38.361), (-79.732, 38.367),
         (-79.735, 38.384), (-79.697, 38.434), (-79.703, 38.489), (-79.67, 38.518), (-79.676, 38.552), (-79.653, 38.596),
         (-79.534, 38.556), (-79.473, 38.462), (-79.312, 38.418), (-79.288, 38.427), (-79.216, 38.497), (-79.134, 38.659),
         (-79.098, 38.664), (-79.098, 38.704), (-79.06, 38.788), (-79.031, 38.797), (-79.002, 38.852), (-78.871, 38.771),
         (-78.79, 38.892), (-78.719, 38.942), (-78.714, 38.915), (-78.682, 38.932), (-78.628, 38.988), (-78.597, 38.976),
         (-78.562, 39.017), (-78.576, 39.036), (-78.413, 39.167), (-78.444, 39.199), (-78.411, 39.234), (-78.424, 39.261),
         (-78.353, 39.34), (-78.373, 39.36), (-78.352, 39.387), (-78.366, 39.409), (-78.347, 39.472), (-77.83, 39.141),
         (-77.734, 39.32), (-77.675, 39.33), (-77.616, 39.309), (-77.564, 39.312), (-77.539, 39.271), (-77.452, 39.227),
         (-77.474, 39.186), (-77.512, 39.166), (-77.516, 39.126), (-77.48, 39.113), (-77.456, 39.079), (-77.339, 39.069),
         (-77.245, 39.032), (-77.24, 38.987), (-77.144, 38.97), (-77.036, 38.875), (-77.025, 38.85), (-77.038, 38.715),
         (-77.118, 38.681), (-77.127, 38.63), (-77.258, 38.581), (-77.252, 38.558), (-77.305, 38.492), (-77.321, 38.444),
         (-77.31, 38.386), (-77.28, 38.347), (-77.243, 38.337), (-77.166, 38.351), (-77.14, 38.374), (-77.087, 38.374),
         (-77.039, 38.406), (-77.007, 38.375), (-77.009, 38.331), (-77.03, 38.317), (-76.957, 38.26), (-76.958, 38.214),
         (-76.838, 38.169), (-76.752, 38.169), (-76.738, 38.138), (-76.703, 38.166), (-76.639, 38.13), (-76.647, 38.153),
         (-76.61, 38.154), (-76.595, 38.113), (-76.534, 38.08), (-76.516, 38.049), (-76.517, 38.042), (-76.536, 38.04),
         (-76.544, 38.028), (-76.468, 38.019), (-76.459, 37.991), (-76.333, 37.949), (-76.231, 37.893), (-76.246, 37.831),
         (-76.278, 37.803), (-76.298, 37.831), (-76.307, 37.828), (-76.304, 37.793), (-76.28, 37.781), (-76.304, 37.775),
         (-76.302, 37.73), (-76.314, 37.728), (-76.297, 37.687), (-76.326, 37.682), (-76.334, 37.657), (-76.327, 37.634),
         (-76.304, 37.647), (-76.273, 37.619), (-76.293, 37.561), (-76.258, 37.479), (-76.275, 37.469), (-76.256, 37.455),
         (-76.242, 37.377), (-76.276, 37.303), (-76.342, 37.359), (-76.34, 37.377), (-76.356, 37.363), (-76.397, 37.387),
         (-76.401, 37.413), (-76.412, 37.413), (-76.407, 37.364), (-76.455, 37.386), (-76.458, 37.364), (-76.443, 37.372),
         (-76.399, 37.342), (-76.362, 37.276), (-76.406, 37.229), (-76.383, 37.226), (-76.395, 37.207), (-76.387, 37.173),
         (-76.402, 37.172), (-76.406, 37.163), (-76.347, 37.176), (-76.266, 37.09), (-76.298, 37.001), (-76.292, 36.975),
         (-76.094, 36.914), (-76.032, 36.938), (-75.988, 36.921), (-75.86, 36.55), (-80.122, 36.537), (-81.681, 36.583),
         (-81.664, 36.606), (-81.919, 36.61), (-81.934, 36.588), (-83.681, 36.599), (-83.651, 36.628), (-83.531, 36.672)],
        [(-76.001, 37.81), (-75.997, 37.856), (-75.969, 37.837), (-75.978, 37.8)],
        [(-76.036, 37.926), (-76.032, 37.957), (-76.014, 37.956), (-76.01, 37.925)]]

    static func contains(_ c: CLLocationCoordinate2D) -> Bool { rings.contains { contains(c, ring: $0) } }

    /// Ray casting: a point is inside when a ray east of it crosses the outline an odd number of times.
    static func contains(_ c: CLLocationCoordinate2D, ring: [(Double, Double)]) -> Bool {
        var inside = false
        var j = ring.count - 1
        for i in 0..<ring.count {
            let (xi, yi) = ring[i], (xj, yj) = ring[j]
            if (yi > c.latitude) != (yj > c.latitude) && c.longitude < (xj - xi) * (c.latitude - yi) / (yj - yi) + xi { inside.toggle() }
            j = i
        }
        return inside
    }
}
