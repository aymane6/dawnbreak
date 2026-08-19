import Foundation

/// The twelve missions that can guard an alarm.
///
/// The raw values are written into the alarm store and into the AlarmKit metadata that
/// survives an app relaunch, so they are stable strings rather than ordinals: inserting
/// a mission in the middle of this enum must not silently rewrite existing alarms.
public enum MissionKind: String, Codable, CaseIterable, Hashable, Sendable, Identifiable {
    case math          // solve arithmetic
    case memory        // reproduce a tile pattern
    case sequence      // repeat a growing colour sequence
    case typing        // type a sentence exactly
    case shake         // shake the phone
    case steps         // walk N steps
    case squats        // squats counted by the front camera
    case photo         // photograph an object you registered
    case barcode       // scan a barcode you registered
    case draw          // draw a named object, recognised on device
    case flap          // clear a lap of the side-scroller
    case breathe       // guided breathing cycles

    public var id: String { rawValue }

    /// Missions that need hardware the simulator and some iPads do not have. The editor
    /// greys these out rather than letting someone arm an alarm they cannot dismiss.
    public var requiredCapability: Capability? {
        switch self {
        case .squats, .photo: .camera
        case .barcode: .camera
        case .steps: .pedometer
        case .shake: .accelerometer
        case .math, .memory, .sequence, .typing, .draw, .flap, .breathe: nil
        }
    }

    public enum Capability: String, Sendable, Hashable {
        case camera, pedometer, accelerometer
    }

    /// A mission that has to be set up before the alarm rings, because it needs a
    /// reference the app cannot invent at 6am (the object to photograph, the barcode
    /// on the cereal box in the kitchen).
    public var needsEnrollment: Bool {
        switch self {
        case .photo, .barcode: true
        default: false
        }
    }

    /// Free tier gets the three that need no hardware and no enrollment. Everything else
    /// is behind the subscription, which is also how the reference app is priced.
    public var isPremium: Bool {
        switch self {
        case .math, .shake, .breathe: false
        default: true
        }
    }

    public var titleKey: String { "mission.\(rawValue).title" }
    public var subtitleKey: String { "mission.\(rawValue).subtitle" }
    public var instructionKey: String { "mission.\(rawValue).instruction" }

    /// SF Symbol. Checked against the SF Symbols 6 inventory shipped with iOS 26.
    public var systemImage: String {
        switch self {
        case .math: "function"
        case .memory: "square.grid.3x3.fill"
        case .sequence: "circle.hexagongrid.fill"
        case .typing: "keyboard"
        case .shake: "iphone.gen3.radiowaves.left.and.right"
        case .steps: "figure.walk"
        case .squats: "figure.strengthtraining.functional"
        case .photo: "camera.viewfinder"
        case .barcode: "barcode.viewfinder"
        case .draw: "pencil.and.scribble"
        case .flap: "bird.fill"
        case .breathe: "wind"
        }
    }

    /// Rough difficulty ordering, used to sort the picker so the gentlest is first.
    public var effortRank: Int {
        switch self {
        case .breathe: 0
        case .shake: 1
        case .math: 2
        case .memory: 3
        case .sequence: 4
        case .typing: 5
        case .draw: 6
        case .barcode: 7
        case .photo: 8
        case .flap: 9
        case .steps: 10
        case .squats: 11
        }
    }
}

/// How hard the chosen mission is. Every mission maps this onto its own parameters
/// (digit count, tile count, step target) in `MissionConfig`.
public enum Difficulty: String, Codable, CaseIterable, Hashable, Sendable, Comparable {
    case easy, medium, hard, brutal

    public static func < (lhs: Difficulty, rhs: Difficulty) -> Bool {
        lhs.rank < rhs.rank
    }

    public var rank: Int {
        switch self {
        case .easy: 0
        case .medium: 1
        case .hard: 2
        case .brutal: 3
        }
    }

    public var titleKey: String { "difficulty.\(rawValue)" }
}
