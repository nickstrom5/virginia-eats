import XCTest
import CoreLocation
@testable import VirginiaEats

@MainActor
final class VirginiaEatsTests: XCTestCase {

    /// A tiny core file and two region detail files with the same shape as Resources/places.json and Resources/detail-*.json.
    private func sampleModel() async throws -> AppModel {
        let json = """
        {"v":1,"generated":"2026-11-05","overture_release":"2026-10-21.0","permits_updated":"",
         "permits_url":"",
         "cities":["Richmond","Chantilly","Alexandria","Middleburg","Washington","Roanoke","Falls Church","Marshall","Wakefield"],
         "cuisines":["Sandwiches & Deli","Chicken & Wings","American & Other","Seafood","European","Burgers","Vietnamese"],
         "brands":["Wawa","King Pollo"],"counties":["City of Richmond","City of Alexandria","Loudoun County","Fairfax County","Rappahannock County","City of Roanoke","Fauquier County","Sussex County"],
         "regions":["Richmond Region","Northern Virginia","Roanoke & Southwest Virginia"],
         "srcs":["official","meta","AllThePlaces","DAC","research"],
         "results":["Passed","Partial Pass"],"ins_jur":["Fairfax Health District"],
         "inspections_through":{"Fairfax Health District":"2026-10-25"},
         "count":12,"count_restaurants":11,
         "calibration":{},
         "places":[
          {"id":"a","n":"Sally Bell's Kitchen","c":0,"co":0,"rg":0,"cu":0,"t":1,"s":1,"hc":1,"g":4,"h":1,"jbf":"America's Classics 2015","a":"2337 W Broad St","la":37.5570,"lo":-77.4600,"dish":"potato salad"},
          {"id":"b","n":"King Pollo of Chantilly","c":1,"co":3,"rg":1,"cu":1,"t":1,"s":1,"hc":1,"g":8,"b":1,"ch":3,"a":"4080 Airline Pkwy","la":38.8930,"lo":-77.4310},
          {"id":"c","n":"Wawa","c":0,"co":0,"rg":0,"cu":2,"t":1,"s":2,"b":0,"ch":90,"la":37.55,"lo":-77.45},
          {"id":"d","n":"Hank's Oyster Bar","c":2,"co":1,"rg":1,"cu":3,"t":1,"s":1,"hc":1,"g":2,"liq":1,"a":"1026 King St","la":38.8050,"lo":-77.0500},
          {"id":"e","n":"Food Lion","c":0,"co":0,"rg":0,"cu":2,"t":1,"s":1,"v":1,"la":37.56,"lo":-77.47},
          {"id":"f","n":"Red Fox Inn & Tavern","c":3,"co":2,"rg":1,"cu":2,"t":1,"s":1,"hc":1,"g":192,"f":1728,"a":"2 E Washington St","la":38.9690,"lo":-77.7355},
          {"id":"g","n":"The Inn at Little Washington","c":4,"co":4,"rg":1,"cu":4,"t":1,"s":1,"hc":1,"g":64,"mi":4,"h":2,"jbf":"Lifetime Achievement winner 2019 (Patrick O'Connell)","a":"309 Middle St","la":38.7130,"lo":-78.1590},
          {"id":"h","n":"Texas Tavern","c":5,"co":5,"rg":2,"cu":5,"t":1,"s":1,"hc":1,"g":132,"f":1930,"a":"114 Church Ave SW","la":37.2710,"lo":-79.9420},
          {"id":"i","n":"Peru 703","c":1,"co":3,"rg":1,"cu":1,"t":1,"s":1,"hc":1,"g":8,"in":[0,0,"2026-09-12"],"a":"5005 Westone Plz","la":38.8690,"lo":-77.4390},
          {"id":"j","n":"Banh Mi So 1","c":6,"co":3,"rg":1,"cu":6,"t":1,"s":1,"hc":1,"g":16,"a":"6799 Wilson Blvd","la":38.8720,"lo":-77.1540},
          {"id":"k","n":"Field & Main Restaurant","c":7,"co":6,"rg":1,"cu":2,"t":1,"s":1,"hc":1,"g":64,"h":4,"jbf":"Outstanding Wine and Other Beverages Program finalist 2026","a":"8369 W Main St","la":38.8650,"lo":-77.8590},
          {"id":"l","n":"Virginia Diner","c":8,"co":7,"rg":0,"cu":2,"t":1,"s":1,"hc":1,"g":5,"a":"408 N County Dr","la":36.9700,"lo":-76.9900,"dish":"country ham; buttermilk biscuits"}
         ]}
        """
        // the license and inspection below are fixtures for the app's record views (Fairfax's permits carry no alcohol license)
        let statewide = """
        {"a":{"lic":[["Example license","1234","Example on-premises license"]],"ph":"(804) 644-2838","w":"sallybellskitchen.example"},
         "c":{"lic":[["Example license","2201","Example on-premises license"],["Example license","2202","Example license (other)"]],"w":"javascript:alert(1)"}}
        """
        let northern = """
        {"d":{"w":"https://hanksoysterbar.example/"},
         "i":{"in":{"n":3,"h":[["2026-09-12",0],["2025-10-14",0],["2025-09-30",1]]},"w":"https://peru703.example/"}}
        """
        let dir = FileManager.default.temporaryDirectory.appendingPathComponent("va-test-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        let url = dir.appendingPathComponent("places.json")
        try json.data(using: .utf8)!.write(to: url)
        try statewide.data(using: .utf8)!.write(to: dir.appendingPathComponent("detail-richmond-region.json"))
        try northern.data(using: .utf8)!.write(to: dir.appendingPathComponent("detail-northern-virginia.json"))
        let model = AppModel(defaults: UserDefaults(suiteName: "test-\(UUID().uuidString)")!)
        await model.load(from: url, detailFolder: dir)
        XCTAssertTrue(model.isLoaded, model.loadError ?? "")
        return model
    }

    func testDecodesAndHidesNonRestaurantsByDefault() async throws {
        let m = try await sampleModel()
        XCTAssertEqual(m.places.count, 12)
        XCTAssertEqual(m.restaurantCount, 11)
        XCTAssertFalse(m.list(.all, sort: .name, search: "", here: nil).contains { $0.name == "Food Lion" }, "a grocery counter is hidden by default")
        m.filters.includeNonRestaurants = true
        XCTAssertTrue(m.list(.all, sort: .name, search: "", here: nil).contains { $0.name == "Food Lion" })
    }

    func testGuidesListOnlyWhatTheyPromise() async throws {
        let m = try await sampleModel()
        XCTAssertEqual(m.list(.hams, sort: .name, search: "", here: nil).map(\.name), ["Virginia Diner"])
        XCTAssertEqual(m.list(.oysters, sort: .name, search: "", here: nil).map(\.name), ["Hank's Oyster Bar"])
        XCTAssertEqual(m.list(.counters, sort: .name, search: "", here: nil).map(\.name), ["Sally Bell's Kitchen", "Texas Tavern", "Virginia Diner"])
        XCTAssertEqual(m.list(.latin, sort: .name, search: "", here: nil).map(\.name), ["King Pollo of Chantilly", "Peru 703"])
        XCTAssertEqual(m.list(.asian, sort: .name, search: "", here: nil).map(\.name), ["Banh Mi So 1"])
        XCTAssertEqual(m.list(.wine, sort: .name, search: "", here: nil).map(\.name), ["Field & Main Restaurant", "Red Fox Inn & Tavern", "The Inn at Little Washington"])
        XCTAssertEqual(m.list(.oldest, sort: .oldest, search: "", here: nil).map(\.name), ["Red Fox Inn & Tavern", "Texas Tavern"])
        let honors = m.list(.honors, sort: .iconic, search: "", here: nil).map(\.name)
        XCTAssertEqual(honors, ["The Inn at Little Washington", "Sally Bell's Kitchen", "Field & Main Restaurant"], "the MICHELIN stars, then America's Classic, then the finalist")
        XCTAssertEqual(m.list(.stew, sort: .name, search: "", here: nil), [], "a guide with nothing hand-checked yet is empty, not padded")
        XCTAssertEqual(m.bibCount, 0)
        XCTAssertEqual(m.place(id: "k")!.jamesBeardLabel, "James Beard finalist")
        XCTAssertEqual(m.place(id: "a")!.jamesBeardLabel, "America's Classic")
    }

    /// "Serves alcohol" comes only from an on-premises license; no license is unknown, never "no" (Virginia's bundled data has none).
    func testServesAlcoholOnlyFromOnPremisesLicenses() async throws {
        let m = try await sampleModel()
        XCTAssertTrue(m.place(id: "d")!.servesAlcohol)
        XCTAssertFalse(m.place(id: "a")!.servesAlcohol, "no on-premises license matched: unknown, not yes")
        XCTAssertEqual(m.alcoholLicenseCount, 1)
    }

    /// A jurisdiction's own result, dated, from the core file; the history from the region file. Nothing is a grade.
    func testInspectionResultsAsTheJurisdictionWordsThem() async throws {
        let m = try await sampleModel()
        let i = m.place(id: "i")!
        XCTAssertEqual(i.inspection.flatMap { m.resultText($0.result) }, "Passed")
        XCTAssertEqual(i.inspection?.date, "2026-09-12")
        XCTAssertEqual(i.inspection.flatMap { m.jurisdictionName($0.jurisdiction) }, "Fairfax Health District")
        let d = await m.detail(for: i)
        XCTAssertEqual(d?.inspection?.n, 3)
        XCTAssertEqual(d?.inspection?.visits.map { m.resultText($0.result) }, ["Passed", "Passed", "Partial Pass"])
        XCTAssertNil(m.place(id: "a")!.inspection, "no result in the data: nothing to show")
        XCTAssertNil(m.resultText(9), "an index the data doesn't have shows nothing")
    }

    func testDatesAreCalendarDays() {
        var utc = Calendar(identifier: .gregorian)
        utc.timeZone = TimeZone(identifier: "UTC")!
        let d = DayFormat.date("2026-06-16")!
        XCTAssertEqual(utc.dateComponents([.year, .month, .day], from: d), DateComponents(year: 2026, month: 6, day: 16))
        XCTAssertTrue(DayFormat.monthYear("2025-09-01")!.contains("2025"))
        XCTAssertNil(DayFormat.date("2026-13-01"))
        XCTAssertEqual(DayFormat.text("August 2025"), "August 2025", "a value that isn't a date is shown as it is")
    }

    func testRegionDetailsLoadOnDemand() async throws {
        let m = try await sampleModel()
        let a = await m.detail(for: m.place(id: "a")!)
        XCTAssertEqual(a?.licenses.first?.id, "1234")
        XCTAssertEqual(a?.website?.absoluteString, "https://sallybellskitchen.example", "a bare host gets https://")
        let c = await m.detail(for: m.place(id: "c")!)
        XCTAssertNil(c?.website, "a javascript: link never becomes a website button")
        XCTAssertEqual(c?.licenses.count, 2)
        let d = await m.detail(for: m.place(id: "d")!)
        XCTAssertEqual(d?.website?.host, "hanksoysterbar.example")
        XCTAssertEqual(AppModel.regionSlug("Fredericksburg & the Northern Neck"), "fredericksburg-the-northern-neck")
        let missing = await m.detail(for: m.place(id: "h")!)
        XCTAssertNil(missing, "a region with no detail file reads as no detail, not a crash")
    }

    func testSearchWordStartsTownsAndGuides() async throws {
        let m = try await sampleModel()
        XCTAssertEqual(m.list(.all, sort: .name, search: "texas", here: nil).map(\.name), ["Texas Tavern"])
        XCTAssertEqual(m.list(.all, sort: .name, search: "wakefield", here: nil).map(\.name), ["Virginia Diner"], "a town narrows to it")
        XCTAssertEqual(m.list(.all, sort: .name, search: "potato salad", here: nil).map(\.name), ["Sally Bell's Kitchen"], "a dish finds who serves it")
        XCTAssertEqual(m.list(.all, sort: .name, search: "🍕", here: nil), [], "an emoji finds nothing, not everything")
        XCTAssertEqual(m.list(.all, sort: .name, search: "pollo a la brasa", here: nil).map(\.name), ["King Pollo of Chantilly", "Peru 703"], "a guide word means the guide")
        XCTAssertEqual(m.list(.all, sort: .name, search: "raw bar", here: nil).map(\.name), ["Hank's Oyster Bar"])
        XCTAssertEqual(m.list(.all, sort: .name, search: "middleburg", here: nil).map(\.name), ["Red Fox Inn & Tavern"], "the town alone is the town")
        XCTAssertEqual(m.list(.all, sort: .name, search: "rappahannock county", here: nil).count, 1, "a county name finds its places")
        XCTAssertEqual(Search.normalize("Phở 777"), "pho 777", "letters folding keeps (ø, đ) are folded too")
    }

    func testOutsideVirginiaUsesTheOutline() {
        func inside(_ la: Double, _ lo: Double) -> Bool { VirginiaOutline.contains(CLLocationCoordinate2D(latitude: la, longitude: lo)) }
        XCTAssertTrue(inside(38.8816, -77.0910), "Arlington"); XCTAssertTrue(inside(38.8048, -77.0469), "Alexandria"); XCTAssertTrue(inside(37.9400, -75.3650), "Chincoteague")
        XCTAssertTrue(inside(36.6083, -82.1617), "Bristol, VA"); XCTAssertTrue(inside(36.853, -75.978), "Virginia Beach"); XCTAssertTrue(inside(39.2726, -77.6372), "Lovettsville")
        XCTAssertFalse(inside(38.8977, -77.0365), "Washington, DC"); XCTAssertFalse(inside(36.5823, -82.1888), "Bristol, TN"); XCTAssertFalse(inside(37.2698, -81.2223), "Bluefield, WV")
        XCTAssertFalse(inside(39.3254, -77.7389), "Harpers Ferry, WV"); XCTAssertFalse(inside(36.4882, -79.7664), "Eden, NC"); XCTAssertFalse(inside(37.33, -122.03), "Cupertino")
    }

    func testBundledData() async throws {
        let m = AppModel(defaults: UserDefaults(suiteName: "bundle-\(UUID().uuidString)")!)
        await m.load()
        XCTAssertTrue(m.isLoaded, m.loadError ?? "")
        XCTAssertGreaterThan(m.restaurantCount, 15_000)
        XCTAssertGreaterThanOrEqual(m.count(.honors), 8)
        XCTAssertEqual(m.bibCount, 0, "the D.C. guide's two Virginia places hold no Bib Gourmand")
        XCTAssertTrue(m.places.contains { $0.name == "The Inn at Little Washington" && $0.michelin == .twoStars })
        XCTAssertEqual(m.alcoholLicenseCount, 0, "Virginia ABC's list isn't used: unknown everywhere, never no")
        XCTAssertEqual(Set(m.places.map(\.id)).count, m.places.count, "ids are unique")
        for g in Guide.allCases where g.tag != nil {
            XCTAssertTrue(m.places.filter(g.includes).allSatisfy(\.handChecked), "\(g.title) lists only hand-checked places")
            if g != .stew { XCTAssertGreaterThanOrEqual(m.count(g), 3, "\(g.title) has a Home card") }
        }
        XCTAssertTrue(m.places.contains { $0.name == "Red Fox Inn & Tavern" && $0.founded == 1728 && $0.handChecked })
        XCTAssertTrue(m.places.contains { $0.name == "Sally Bell's Kitchen" && $0.jamesBeardLabel == "America's Classic" && $0.handChecked })
        XCTAssertTrue(m.places.contains { $0.name == "Field & Main Restaurant" && $0.jamesBeardLabel == "James Beard finalist" })
        let fairfax: Set<String> = ["Fairfax County", "City of Fairfax", "City of Falls Church"]
        let inspected = m.places.filter { $0.inspection != nil }
        XCTAssertGreaterThan(inspected.count, 1_000, "Fairfax's results are attached")
        XCTAssertTrue(inspected.allSatisfy { fairfax.contains($0.county ?? "") }, "results only where the Fairfax Health District inspects")
        // no Google-derived data: the data file has no rating, review or price fields at all
        let raw = try String(contentsOf: Bundle.main.url(forResource: "places", withExtension: "json")!, encoding: .utf8)
        for key in ["\"rating\"", "\"reviews\"", "\"price\"", "\"gmap_id\""] { XCTAssertFalse(raw.contains(key), "\(key) must not ship") }
    }

    /// Stable ids: md5(name + ~100 m cell)[:12], never a row number; every bundled region detail file decodes and its ids are core ids.
    func testIdsAndBundledDetailFiles() async throws {
        let m = AppModel(defaults: UserDefaults(suiteName: "ids-\(UUID().uuidString)")!)
        await m.load()
        XCTAssertTrue(m.places.allSatisfy { $0.id.count >= 12 && $0.id.prefix(12).allSatisfy(\.isHexDigit) && $0.id.dropFirst(12).allSatisfy { $0 == "x" } })
        let ids = Set(m.places.map(\.id))
        var detailed = 0
        for region in Set(m.places.compactMap(\.region)) {
            let url = try XCTUnwrap(Bundle.main.url(forResource: "detail-" + AppModel.regionSlug(region), withExtension: "json"), region)
            let d = try JSONDecoder().decode([String: PlaceDetail].self, from: Data(contentsOf: url))
            XCTAssertTrue(Set(d.keys).isSubset(of: ids), "\(region) detail ids are core ids")
            XCTAssertTrue(d.values.allSatisfy { $0.licenses.allSatisfy { $0.source == "Fairfax Health District food permit" } }, "\(region): the only license records are Fairfax's permits")
            detailed += d.count
        }
        XCTAssertGreaterThan(detailed, 2_000, "places with a phone or website have a detail record")
    }

    func testBundledDataGuards() async throws {
        let m = AppModel(defaults: UserDefaults(suiteName: "guards-\(UUID().uuidString)")!)
        await m.load()
        XCTAssertTrue(m.isLoaded, m.loadError ?? "")
        XCTAssertEqual(DataGuards.adultVenues(m.places), [], "no strip club under its name")
        XCTAssertEqual(DataGuards.badWebsites(try DataGuards.bundledLinks(m.places)), [], "no directory, Google or news page as a restaurant's website")
        XCTAssertEqual(DataGuards.badNames(m.places), [], "no visible name ending in \u{201C} the\u{201D} or \u{201C} of\u{201D}, or just \u{201C}The\u{201D}")
        XCTAssertEqual(DataGuards.legalNames(m.places), [], "no license holder entity name (\u{201C}… LLC\u{201D}) shown as a place's name")
        XCTAssertEqual(DataGuards.nonRestaurants(m.places), [], "no nail salon, senior home, gun store or gas station among the restaurants")
        XCTAssertEqual(DataGuards.listedTwice(m.places), [], "no place listed twice (same name, street address and town) with pins apart")
        let raw = try DataGuards.bundledLinks(m.places, raw: true)
        XCTAssertGreaterThan(raw.count, 3_000, "the detail files carry websites")
        XCTAssertEqual(DataGuards.notOneURL(raw), [], "every website is one URL, with no spaces")
    }

    /// Each guard above fires on a copy of the bundled data broken the way QA found it elsewhere: a guard that can't fail guards nothing.
    func testGuardsCatchABrokenCopy() async throws {
        let raw = try Data(contentsOf: Bundle.main.url(forResource: "places", withExtension: "json")!)
        var file = try XCTUnwrap(JSONSerialization.jsonObject(with: raw) as? [String: Any])
        var places = try XCTUnwrap(file["places"] as? [[String: Any]])
        let idx = places.indices.filter { places[$0]["v"] == nil }.prefix(7).map { $0 }
        places[idx[2]]["n"] = "Bourbon Street Gentlemen's Club"
        // the same place twice, 2 km apart (QA 2026-10-29 P1 #7)
        var twin = places[idx[0]]
        twin["id"] = "twin00000000"
        twin["la"] = ((twin["la"] as? Double) ?? 30.0) + 0.02
        places.append(twin)
        places[idx[3]]["n"] = "Kitchen the"
        places[idx[4]]["n"] = "OLD LINE HOSPITALITY GROUP LLC"
        places[idx[5]]["n"] = "Tipsy Nails & Spa"
        places[idx[6]]["n"] = "The Meltdown"
        file["places"] = places
        let url = FileManager.default.temporaryDirectory.appendingPathComponent("places-broken.json")
        try JSONSerialization.data(withJSONObject: file).write(to: url)
        let m = AppModel(defaults: UserDefaults(suiteName: "broken-\(UUID().uuidString)")!)
        await m.load(from: url)
        XCTAssertTrue(m.isLoaded, m.loadError ?? "")
        let id = idx.map { places[$0]["id"] as? String }
        func caught(_ found: [String], _ i: Int, _ what: String) {
            XCTAssertTrue(found.contains { $0.contains("[\(id[i] ?? "?")]") }, "the guard missed \(what)")
        }
        let links = [(name: "A", id: "x1", url: "https://www.yelp.com/biz/some-place"), (name: "B", id: "x2", url: "https://www.baltimoresun.com/2026/03/01/a-story/"),
                     (name: "C", id: "x3", url: "https://smart.com/menu")]
        XCTAssertEqual(DataGuards.badWebsites(links).count, 2, "the guard catches a Yelp page and a news story, and not smart.com")
        let messy = [(name: "D", id: "x4", url: "https://togoorder.com/web/1754#/ (Order Online)"), (name: "E", id: "x5", url: "https://bubbakoos.com/a,https://bubbakoos.com/b"),
                     (name: "F", id: "x6", url: "https://hammeredharrys.com/locations/las-vegas-fremont-s ."), (name: "G", id: "x7", url: "instagram.com/sharks1413_macon"),
                     (name: "H", id: "x8", url: "https://togoorder.com/web/1754#/"), (name: "I", id: "x9", url: "https://x.example/menu?a=1&b=2#top")]
        XCTAssertEqual(DataGuards.notOneURL(messy).count, 3, "the guard catches a label after a link, two links run together and a stray \" .\", not a bare host")
        caught(DataGuards.adultVenues(m.places), 2, "a gentlemen's club")
        caught(DataGuards.badNames(m.places), 3, "\u{201C}Kitchen the\u{201D}")
        caught(DataGuards.legalNames(m.places), 4, "a license holder's entity name")
        caught(DataGuards.nonRestaurants(m.places), 5, "a nail salon shown as a restaurant")
        caught(DataGuards.nonRestaurants(m.places), 6, "a Denny's delivery-only brand shown as a restaurant (QA 2026-10-29)")
        XCTAssertTrue(DataGuards.listedTwice(m.places).contains { $0.contains("[twin00000000]") || $0.contains("[\(id[0] ?? "?")]") },
                      "the guard missed a place listed twice with pins 2 km apart")
    }
}

/// Checks on the bundled data, written as functions so testGuardsCatchABrokenCopy can prove each one fires.
enum DataGuards {
    /// directories, Google and news sites: matched on the link's host, so "smart.com" isn't "rt.com"
    static let badHosts = #"^https?://([^/?#]*\.)?(yelp\.com|business\.site|google\.com|groupon\.com|yellowpages\.com|tripadvisor\.com|baltimoresun\.com|thebaltimorebanner\.com|baltimoremagazine\.com|wbaltv\.com|foxbaltimore\.com|capitalgazette\.com|washingtonian\.com|baltimore\.org|visitvirginia\.org|eater\.com|rt\.com)([:/?#]|$)"#

    static func badWebsites(_ links: [(name: String, id: String, url: String)]) -> [String] {
        links.compactMap { l in
            guard l.url.range(of: badHosts, options: [.regularExpression, .caseInsensitive]) != nil else { return nil }
            return "\(l.name) [\(l.id)]: \(l.url)"
        }
    }

    /// every website in the bundled region detail files, with its place's name: as the app opens it, or (raw) exactly as the data writes it
    static func bundledLinks(_ places: [Place], raw: Bool = false) throws -> [(name: String, id: String, url: String)] {
        let names = Dictionary(places.map { ($0.id, $0.name) }, uniquingKeysWith: { a, _ in a })
        var out: [(name: String, id: String, url: String)] = []
        for region in Set(places.compactMap(\.region)) {
            guard let url = Bundle.main.url(forResource: "detail-" + AppModel.regionSlug(region), withExtension: "json") else { continue }
            for (id, d) in try JSONDecoder().decode([String: PlaceDetail].self, from: Data(contentsOf: url)) {
                if let w = raw ? d.w : d.website?.absoluteString { out.append((names[id] ?? "?", id, w)) }
            }
        }
        return out
    }

    /// a website that isn't one web address: a space ("https://togoorder.com/web/1754#/ (Order Online)"), a second link run on
    /// ("https://bubbakoos.com/a,https://bubbakoos.com/b"), or no web host even with https:// given to a bare one, as the app does
    /// (QA 2026-10-28, P1 #7; scripts/qa-site.py's website_problem)
    static func notOneURL(_ links: [(name: String, id: String, url: String)]) -> [String] {
        links.filter { l in
            if l.url.rangeOfCharacter(from: .whitespacesAndNewlines) != nil
                || l.url.range(of: #"(?i)https?://.*https?://|.[,;|]\s*www\."#, options: .regularExpression) != nil { return true }
            guard let u = URL(string: l.url.contains("://") ? l.url : "https://" + l.url), ["http", "https"].contains(u.scheme?.lowercased() ?? ""),
                  let host = u.host, host.contains(".") else { return true }
            return false
        }.map { "\($0.name) [\($0.id)]: \($0.url)" }
    }

    /// the pipeline's widened rule (ohio.py and texas.py after QA 2026-10-29, as ported to virginia.py)
    static let adultNames = #"gentlem[ae]n['’]?s? (?:club|lounge)|strip club|exotic dancer|\bmen['’]?s club|rick['’]?s cabaret|xtc cabaret|baby dolls|spearmint rhino|bikini bar|pt['’]?s showclub|showgirls|centerfolds|treasures? gentlem|\btopless\b|male exotic|\bgold club\b|peppermint hippo|stilettos? cabaret|deja ?vu showgirls|hustler club|penthouse club"#

    /// every permit or license number in the bundled region detail files, by place id
    static func bundledLicenses(_ places: [Place]) throws -> [String: [String]] {
        var out: [String: [String]] = [:]
        for region in Set(places.compactMap(\.region)) {
            guard let url = Bundle.main.url(forResource: "detail-" + AppModel.regionSlug(region), withExtension: "json") else { continue }
            for (id, d) in try JSONDecoder().decode([String: PlaceDetail].self, from: Data(contentsOf: url)) where !d.licenses.isEmpty {
                out[id] = d.licenses.compactMap(\.id)
            }
        }
        return out
    }

    static func adultVenues(_ places: [Place]) -> [String] {
        places.filter { $0.name.range(of: adultNames, options: [.regularExpression, .caseInsensitive]) != nil }.map { "\($0.name) [\($0.id)]" }
    }

    /// a name cut off after "the" or "of" ("Kitchen the", "Wines of") or nothing but "The", among the places shown by default
    static func badNames(_ places: [Place]) -> [String] {
        places.filter { p in
            let n = p.name.trimmingCharacters(in: .whitespaces).lowercased()
            return !p.isVenue && (n.hasSuffix(" the") || n.hasSuffix(" of") || n == "the")
        }.map { "\($0.name) [\($0.id)]" }
    }

    /// a license holder (owner) is never shown; a business name that's still a legal entity shouldn't be either
    static let legalSuffix = #"\b(llc|l\.l\.c|inc|corp|corporation)\.?$"#

    static func legalNames(_ places: [Place]) -> [String] {
        places.filter { !$0.isVenue && $0.name.range(of: legalSuffix, options: [.regularExpression, .caseInsensitive]) != nil }
            .map { "\($0.name) [\($0.id)]" }
    }

    /// businesses that aren't places to eat, among the places shown by default
    /// and delivery-only brands cooked in another restaurant's kitchen: Denny's The Meltdown, The Burger Den and Banda Burrito (QA 2026-10-29)
    static let nonRestaurantNames = #"\bnails?\b|assisted living|gun (?:club|range|shop|store)|shooting range|firearms|petroleum|\bauto (?:repair|parts)\b|^(?:the )?(?:meltdown|burger den)$|banda burrito|tenderfix|pardon my cheesesteak|neighborhood wings"#

    /// the same place twice: one normalized name at one street address in one town, shown by default, pins at least 1 km apart
    /// (QA 2026-10-29 P1 #7; sc-eats' DataGuards.listedTwice)
    static func listedTwice(_ places: [Place]) -> [String] {
        var seen: [String: Place] = [:], out: [String] = []
        for p in places where !p.isVenue {
            guard let a = p.address, !a.isEmpty, let l = p.location else { continue }
            let k = Search.normalize(p.name) + "|" + Search.normalizeAddress(a) + "|" + (p.city ?? "")
            if let q = seen[k], let m = q.location, l.distance(from: m) >= 1_000 { out.append("\(p.name) [\(p.id)] and [\(q.id)]") }
            else { seen[k] = p }
        }
        return out
    }

    static func nonRestaurants(_ places: [Place]) -> [String] {
        places.filter { !$0.isVenue && $0.name.range(of: nonRestaurantNames, options: [.regularExpression, .caseInsensitive]) != nil }
            .map { "\($0.name) [\($0.id)]" }
    }
}

/// pipeline/website_blocklist.json (hacked, taken-over, expired or another business's sites, confirmed by hand in the link sweeps):
/// no link on it may ship in any field of any JSON file the app bundles. The 2026-10-19 QA found the export had only filtered the
/// website field, or nothing, so hijacked links were still in the bundle. Read from the repo, so a new entry needs no code change.
final class LinkBlocklistTests: XCTestCase {
    func testNoBlocklistedLinkInBundledData() throws {
        let entries = try LinkBlocklist.entries()
        XCTAssertFalse(entries.isEmpty, "the blocklist is missing or empty")
        let files = LinkBlocklist.bundledJSON()
        XCTAssertFalse(files.isEmpty, "no bundled JSON found")
        var hits: [String] = []
        for url in files {
            let text = try String(contentsOf: url, encoding: .utf8)
            hits += LinkBlocklist.hits(in: text, entries).map { "\(url.lastPathComponent): \($0)" }
        }
        XCTAssertEqual(hits, [], "blocklisted links in the app's bundled data")
    }

    /// The guard fires on a copy of the bundled data broken three ways: a blocklisted domain, its subdomain, and a "url" entry.
    func testBlocklistGuardCatchesABrokenCopy() throws {
        let entries = try LinkBlocklist.entries()
        let file = try XCTUnwrap(LinkBlocklist.bundledJSON().max { (try? $0.resourceValues(forKeys: [.fileSizeKey]).fileSize ?? 0) ?? 0 < (try? $1.resourceValues(forKeys: [.fileSizeKey]).fileSize ?? 0) ?? 0 })
        let text = try String(contentsOf: file, encoding: .utf8)
        let domain = try XCTUnwrap(entries.first { ($0["match"] as? String ?? "domain") == "domain" }?["domain"] as? String)
        let fake: [[String: Any]] = entries + [["match": "url", "url": "https://example.org/hacked-page"]]
        let before = LinkBlocklist.hits(in: text, fake).count
        let broken = text + "{\"w\":\"https://www.\(domain)/menu\"}{\"src\":\"http://shop.\(domain)/\"}{\"w\":\"https://example.org/hacked-page/\"}"
        XCTAssertEqual(LinkBlocklist.hits(in: broken, fake).count, before + 3, "a domain, a subdomain and a url entry are all caught")
        XCTAssertEqual(LinkBlocklist.hits(in: "{\"w\":\"https://not\(domain)/\"}", entries), [], "a host that only ends with the domain's letters isn't it")
    }
}

enum LinkBlocklist {
    static func entries() throws -> [[String: Any]] {
        let url = URL(fileURLWithPath: #filePath).deletingLastPathComponent().deletingLastPathComponent()
            .appendingPathComponent("pipeline/website_blocklist.json")
        return try XCTUnwrap(JSONSerialization.jsonObject(with: Data(contentsOf: url)) as? [[String: Any]])
    }

    /// every .json file in the app bundle, subfolders included
    static func bundledJSON() -> [URL] {
        let root = Bundle.main.bundleURL
        let all = FileManager.default.enumerator(at: root, includingPropertiesForKeys: nil)?.allObjects as? [URL] ?? []
        return all.filter { $0.pathExtension == "json" && !$0.path.contains("/PlugIns/") }
    }

    private static func host(_ u: URLComponents) -> String {
        var h = (u.host ?? "").lowercased()
        if h.hasSuffix(".") { h.removeLast() }
        return h.hasPrefix("www.") ? String(h.dropFirst(4)) : h
    }

    private static func trimmedPath(_ p: String) -> String { p.hasSuffix("/") ? String(p.dropLast()) : p }

    /// the links in a JSON text that an entry covers: a "domain" entry its domain and subdomains, a "url" entry that page only
    static func hits(in text: String, _ entries: [[String: Any]]) -> [String] {
        let t = text.replacingOccurrences(of: "\\/", with: "/")
        let rx = try! NSRegularExpression(pattern: #"https?://[^"\s\\]+"#, options: [.caseInsensitive])
        return rx.matches(in: t, range: NSRange(t.startIndex..., in: t)).compactMap { m -> String? in
            let s = String(t[Range(m.range, in: t)!])
            guard let u = URLComponents(string: s) else { return nil }
            let h = host(u)
            for e in entries {
                if (e["match"] as? String ?? "domain") == "url" {
                    guard let v = URLComponents(string: e["url"] as? String ?? "") else { continue }
                    if !h.isEmpty && h == host(v) && trimmedPath(u.path) == trimmedPath(v.path) { return s }
                } else {
                    var d = (e["domain"] as? String ?? "").lowercased()
                    if let r = d.range(of: "://") { d = String(d[r.upperBound...]) }
                    d = String(d.split(separator: "/").first ?? "")
                    if d.hasPrefix("www.") { d = String(d.dropFirst(4)) }
                    if !d.isEmpty && (h == d || h.hasSuffix("." + d)) { return s }
                }
            }
            return nil
        }
    }
}

/// QA 2026-10-19, P1 3a: the support address is nick@eatsranked.com (Nick, 2026-10-12). The old Gmail address must not come back
/// anywhere in the app's source or bundled files.
final class SupportEmailTests: XCTestCase {
    func testSupportEmailIsEatsRanked() {
        XCTAssertEqual(Links.supportEmail, "nick@eatsranked.com")
    }

    func testNoGmailInAppSource() throws {
        let root = URL(fileURLWithPath: #filePath).deletingLastPathComponent().deletingLastPathComponent()
            .appendingPathComponent("VirginiaEats")
        XCTAssertGreaterThan(SupportEmailScan.textFiles(under: root).count, 5, "the app's source folder wasn't found")
        XCTAssertEqual(SupportEmailScan.hits(under: root), [], "the app's source still has a Gmail address")
    }

    /// The guard fires on a broken copy: a folder with one planted Gmail address.
    func testGmailGuardCatchesABrokenCopy() throws {
        let dir = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: dir.appendingPathComponent("App"), withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: dir) }
        try "static let supportEmail = \"someone@GMAIL.com\"\n".write(to: dir.appendingPathComponent("App/Links.swift"), atomically: true, encoding: .utf8)
        try "{\"ok\": \"nick@eatsranked.com\"}".write(to: dir.appendingPathComponent("App/data.json"), atomically: true, encoding: .utf8)
        XCTAssertEqual(SupportEmailScan.hits(under: dir), ["App/Links.swift"])
    }
}

enum SupportEmailScan {
    static let textExtensions: Set<String> = ["swift", "plist", "json", "strings", "xcstrings", "xcprivacy", "md", "txt", "html", "entitlements"]

    static func textFiles(under root: URL) -> [URL] {
        let all = FileManager.default.enumerator(at: root, includingPropertiesForKeys: nil)?.allObjects as? [URL] ?? []
        return all.filter { textExtensions.contains($0.pathExtension.lowercased()) }
    }

    /// paths (relative to root) of text files that mention gmail.com, in any case
    static func hits(under root: URL) -> [String] {
        let base = root.resolvingSymlinksInPath().path + "/"
        return textFiles(under: root).compactMap { url in
            guard let text = try? String(contentsOf: url, encoding: .utf8),
                  text.range(of: "gmail.com", options: .caseInsensitive) != nil else { return nil }
            return url.resolvingSymlinksInPath().path.replacingOccurrences(of: base, with: "")
        }.sorted()
    }
}

/// QA 2026-10-19, P1 #13: outbound links ship without tracking tags (ref=google, referrer=google_food_ordering, cn_channel, utm_* …).
/// pipeline/tracking_params.py strips them in the export; these are the same rules.
final class TrackingParamTests: XCTestCase {
    func testNoTrackingParametersInBundledLinks() throws {
        let files = TrackingParams.bundledJSON()
        XCTAssertFalse(files.isEmpty, "no bundled JSON found")
        var hits: [String] = []
        for url in files {
            let text = try String(contentsOf: url, encoding: .utf8)
            hits += TrackingParams.tracked(in: text).map { "\(url.lastPathComponent): \($0)" }
        }
        XCTAssertEqual(hits, [], "links with tracking parameters in the app's bundled data")
    }

    /// The guard fires on a broken copy (four kinds of tracking tag, one in escaped JSON; then Georgia's four from QA 2026-10-28: after
    /// "#", in the path, without a scheme and Klaviyo's _kx) and leaves a store's own parameters, anchors and routes alone.
    func testTrackingGuardCatchesABrokenCopy() {
        let broken = #"[{"w":"https:\/\/places.example.com\/menu?ref=google"},{"w":"https://a.example/?utm_source=gmb&store=4"},"#
            + #"{"w":"https://b.example/x?referrer=google_food_ordering"},{"w":"https://c.example/order/1?cn_channel=cn_google"}]"#
        XCTAssertEqual(TrackingParams.tracked(in: broken).count, 4)
        // QA 2026-10-28 (P1 #4): Hard Rock Atlanta's Yext tag after "#", Snooze Alpharetta's tags written into the path, a Macon
        // Instagram link stored without a scheme, and Paul Thomas Chocolates' Klaviyo _kx
        let hidden = #"[{"w":"https:\/\/cafe.hardrock.com\/atlanta\/#utm_source=rest_of_network&utm_medium=Yext"},"#
            + #"{"w":"https://www.snoozeeatery.com/restaurant/georgia/alpharetta/utm_source=Facebook&utm_medium=BusinessListing"},"#
            + #"{"w":"instagram.com\/sharks1413_macon?igshid=NjNlMDhmYTc%3D"},"#
            + #"{"w":"https://paulthomaschocolates.com/pages/free-tasting-event?_kx=aSsBlo5n7gs8XtzVMZqf49qCxiL8_rle28VLXim4X1o.V26kig"}]"#
        XCTAssertEqual(TrackingParams.tracked(in: hidden).count, 4)
        let clean = #"[{"w":"https://order.example.com/menu?restaurantId=51&location=7"},{"w":"https://shop.example.com/?cid=12&ref=gs"},"#
            + #"{"w":"https://a.example.com/#menu"},{"w":"https://b.example.com/#/order?table=4"},{"w":"instagram.com/sharks1413_macon"}]"#
        XCTAssertEqual(TrackingParams.tracked(in: clean), [])
    }
}

enum TrackingParams {
    /// tracking by name, whatever the value
    static let keys = try! NSRegularExpression(pattern: #"^(?:utm[_-].*|gclid|gbraid|wbraid|dclid|fbclid|msclkid|mc_cid|mc_eid|_ga|_gl|_kx|igsh|"#
        + #"igshid|mibextid|srsltid|cn_channel|y_source|rwg_token|olonwp|ost_redirect_attribution|cmpid|yext_?.*)$"#, options: [.caseInsensitive])
    /// tracking only with these values
    static let values: [String: String] = ["ref": #"^(?:google|gmb|gbp|yext|bookmarks)\b"#, "referrer": "^google",
                                           "source": #"^(?:google|gmb|gbp|yext)\b"#, "cid": "^RF:YXT", "cmp": "^OKC-"]

    /// every .json file in the app bundle, subfolders included
    static func bundledJSON() -> [URL] {
        let all = FileManager.default.enumerator(at: Bundle.main.bundleURL, includingPropertiesForKeys: nil)?.allObjects as? [URL] ?? []
        return all.filter { $0.pathExtension == "json" && !$0.path.contains("/PlugIns/") }
    }

    static func isTracking(_ key: String, _ value: String) -> Bool {
        let k = key.trimmingCharacters(in: .whitespaces)
        if keys.firstMatch(in: k, range: NSRange(k.startIndex..., in: k)) != nil { return true }
        guard let pattern = values[k.lowercased()] else { return false }
        return value.trimmingCharacters(in: .whitespaces).range(of: pattern, options: [.regularExpression, .caseInsensitive]) != nil
    }

    /// links in a JSON text that still carry a tracking tag: in the query, after "#" (a route's own query, or "#utm_source=…"), or
    /// written into the path ("…/alpharetta/utm_source=Facebook&utm_medium=BusinessListing"), with or without a scheme
    /// ("instagram.com/x?igshid=…"); pipeline/tracking_params.py's rules since QA 2026-10-28 (P1 #4)
    static func tracked(in text: String) -> [String] {
        let t = text.replacingOccurrences(of: "\\/", with: "/").replacingOccurrences(of: "&amp;", with: "&")
        let rx = try! NSRegularExpression(pattern: #"https?://[^\s"'<>\\]+|(?<![\w/.:@-])(?:[a-z0-9-]+\.)+[a-z]{2,}/[^\s"'<>\\]*"#,
                                          options: [.caseInsensitive])
        return rx.matches(in: t, range: NSRange(t.startIndex..., in: t)).compactMap { m -> String? in
            let s = String(t[Range(m.range, in: t)!])
            return isTracked(s) ? s : nil
        }
    }

    static func isTracked(_ link: String) -> Bool {
        var rest = Substring(link)
        var fragment: Substring = ""
        if let h = rest.firstIndex(of: "#") { fragment = rest[rest.index(after: h)...]; rest = rest[..<h] }
        var query: Substring = ""
        if let q = rest.firstIndex(of: "?") { query = rest[rest.index(after: q)...]; rest = rest[..<q] }
        if hasTracking(query) { return true }
        if fragment.contains("=") {
            let tail = fragment.lastIndex(of: "?").map { fragment[fragment.index(after: $0)...] } ?? fragment
            if hasTracking(tail) { return true }
        }
        let afterScheme = rest.range(of: "://").map { rest[$0.upperBound...] } ?? rest
        let path = afterScheme.firstIndex(of: "/").map { afterScheme[$0...] } ?? ""
        return path.split(separator: "/").contains { $0.contains("=") && hasTracking($0) }
    }

    /// "k=v&k2=v2" holds a tracking pair
    static func hasTracking(_ params: Substring) -> Bool {
        for part in params.split(separator: "&") {
            let kv = part.split(separator: "=", maxSplits: 1, omittingEmptySubsequences: false)
            let k = String(kv[0]).replacingOccurrences(of: "+", with: " ").removingPercentEncoding ?? String(kv[0])
            let v = kv.count > 1 ? (String(kv[1]).replacingOccurrences(of: "+", with: " ").removingPercentEncoding ?? String(kv[1])) : ""
            if isTracking(k, v) { return true }
        }
        return false
    }
}

/// No Google-derived data ships: the app's calibration once carried Google 2021's open share per listing group (QA 2026-10-28, GA-1;
/// the same guard as sc-eats). Only the private web leaderboard may use the 2021 snapshot.
final class NoGoogleDataTests: XCTestCase {
    /// a key that names Google or something only Google's snapshot supplies
    static let googleKey = try! NSRegularExpression(pattern: "google|rating|review|gmap|price|in21|closed21", options: [.caseInsensitive])

    /// every Google-derived key in a decoded JSON value, as "path.key"
    static func googleKeys(in value: Any, path: String = "") -> [String] {
        if let d = value as? [String: Any] {
            return d.flatMap { k, v -> [String] in
                let here = path.isEmpty ? k : path + "." + k
                let hit = googleKey.firstMatch(in: k, range: NSRange(k.startIndex..., in: k)) != nil ? [here] : []
                return hit + googleKeys(in: v, path: here)
            }
        }
        if let a = value as? [Any] { return a.flatMap { googleKeys(in: $0, path: path + "[]") } }
        return []
    }

    func testNoGoogleDerivedKeyInBundledData() throws {
        let files = Bundle.main.urls(forResourcesWithExtension: "json", subdirectory: nil) ?? []
        XCTAssertFalse(files.isEmpty, "no bundled JSON found")
        var hits = Set<String>()
        for url in files {
            let value = try JSONSerialization.jsonObject(with: Data(contentsOf: url))
            for k in Self.googleKeys(in: value) { hits.insert(url.lastPathComponent + ": " + k) }
        }
        XCTAssertEqual(hits.sorted(), [], "Google-derived data in the app bundle")
    }

    /// The guard fires on a copy broken the way the first export was (an area's open_google_2021 shares) and on a place rating.
    func testGuardCatchesABrokenCopy() {
        let area = "Example County (food service facilities inspected since 2025-05)"
        let broken: [String: Any] = ["calibration": [area: ["groups": ["meta_high": ["n": 18644, "official": 0.192]],
                                                            "open_google_2021": ["meta_high": 0.706]]],
                                     "places": [["id": "x", "n": "Somewhere", "rating": 4.5]]]
        XCTAssertEqual(Set(Self.googleKeys(in: broken).map { $0.components(separatedBy: ".").last! }), ["open_google_2021", "rating"])
        XCTAssertEqual(Self.googleKeys(in: ["calibration": [area: ["groups": ["meta_high": ["n": 1, "official": 0.8]]]]]), [],
                       "the calibration the app needs passes")
    }
}
