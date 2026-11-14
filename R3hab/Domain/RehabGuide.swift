import Foundation

/// Short stage map for the Guide screen. Condensed from the phase notes:
/// calm the tendon, heavy slow resistance, spring, then sport.
struct RehabStage: Equatable, Identifiable, Sendable {
    var id: String
    var title: String
    var purpose: String
    var bullets: [String]
}

enum RehabGuide {
    static let intro = "Four stages. Stay with a stage while the next morning is still louder than usual. Move on when mornings are calm again."

    static let stages: [RehabStage] = [
        RehabStage(
            id: "isometrics",
            title: "Isometrics",
            purpose: "Calm an irritable tendon and start loading it without bending and straightening under load.",
            bullets: [
                "Seated leg extension holds. Mild pain during the hold can be acceptable.",
                "Useful early, including on days you are not doing heavy sets.",
                "Move on after a few mornings in a row are back to your usual baseline."
            ]
        ),
        RehabStage(
            id: "hsr",
            title: "Isotonic / heavy slow resistance",
            purpose: "Build tendon strength with slow, heavy reps.",
            bullets: [
                "Leg extension and leg press. About 3 seconds up and 3 seconds down.",
                "Add a little weight when you finish the sets and the next morning stays quiet.",
                "Change one thing at a time. Keep the holds as a warm-up if they help."
            ]
        ),
        RehabStage(
            id: "energy",
            title: "Energy storage / plyometrics",
            purpose: "Teach the tendon to store and release energy. This comes after heavy slow work feels steady.",
            bullets: [
                "Add one drill at a time: hops, then jump-ups, then landings.",
                "Keep two heavier strength days beside the plyometric day.",
                "Add the next drill only when the next morning does not flare."
            ]
        ),
        RehabStage(
            id: "sport",
            title: "Return to sport",
            purpose: "Bring tennis or training back on top of the strength work, not instead of it.",
            bullets: [
                "Start with short, planned sport sessions.",
                "Increase time only when the next morning stays at baseline.",
                "A louder morning means less sport for now, then rebuild."
            ]
        )
    ]

    static let caution = "Sharp joint pain, swelling, locking, or giving way is a reason to stop and see a clinician. This screen is a personal note, not a medical device."
}
