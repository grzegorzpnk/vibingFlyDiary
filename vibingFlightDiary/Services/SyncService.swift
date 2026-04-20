import Foundation
import SwiftData
import FirebaseFirestore
import FirebaseAuth

/// Syncs local SwiftData flights to/from Firestore.
///
/// Write flow  : SwiftData first (instant UI) → push to Firestore (queued by SDK if offline)
/// Read flow   : Firestore real-time listener → upsert into SwiftData
/// Offline     : Firestore SDK queues writes and flushes automatically when back online
@Observable
final class SyncService {

    // Exposed so UI can show a subtle sync indicator if desired
    private(set) var isSyncing = false

    private var db: Firestore { Firestore.firestore() }
    private var listener: ListenerRegistration?
    private var currentUID: String?
    private var modelContext: ModelContext?

    // MARK: - Lifecycle

    /// Call once from the App on launch.  Watches Firebase auth state and
    /// starts/stops the Firestore listener automatically.
    func start(modelContext: ModelContext) {
        self.modelContext = modelContext

        Auth.auth().addStateDidChangeListener { [weak self] _, user in
            guard let self else { return }
            if let uid = user?.uid {
                self.startListener(uid: uid)
            } else {
                self.stopListener()
            }
        }
    }

    // MARK: - Public write API

    /// Push one flight to Firestore.  Safe to call while offline — SDK queues it.
    func push(_ flight: Flight) {
        guard let uid = Auth.auth().currentUser?.uid else { return }

        var data: [String: Any] = [
            "originIATA":      flight.originIATA,
            "destinationIATA": flight.destinationIATA,
            "date":            Timestamp(date: flight.date),
            "distanceKm":      flight.distanceKm,
            "updatedAt":       FieldValue.serverTimestamp(),
            "deleted":         false
        ]
        if let v = flight.seatType     { data["seatType"]     = v.rawValue }
        if let v = flight.flightClass  { data["flightClass"]  = v.rawValue }
        if let v = flight.airline      { data["airline"]      = v }
        if let v = flight.flightNumber { data["flightNumber"] = v }
        if let v = flight.aircraftType { data["aircraftType"] = v }

        userFlights(uid: uid).document(flight.id.uuidString).setData(data, merge: true)
    }

    /// Soft-delete a flight in Firestore so other devices remove it too.
    func delete(flightId: UUID) {
        guard let uid = Auth.auth().currentUser?.uid else { return }
        userFlights(uid: uid).document(flightId.uuidString).updateData([
            "deleted":   true,
            "updatedAt": FieldValue.serverTimestamp()
        ])
    }

    // MARK: - Private: listener

    private func startListener(uid: String) {
        guard uid != currentUID else { return }
        stopListener()
        currentUID = uid
        isSyncing  = true

        listener = userFlights(uid: uid)
            .whereField("deleted", isEqualTo: false)
            .addSnapshotListener { [weak self] snapshot, _ in
                guard let self, let changes = snapshot?.documentChanges else {
                    self?.isSyncing = false
                    return
                }
                for change in changes {
                    switch change.type {
                    case .added, .modified: self.upsert(doc: change.document)
                    case .removed:          self.deleteLocal(idString: change.document.documentID)
                    }
                }
                self.isSyncing = false
            }

        // Upload any locally-held flights that Firestore doesn't know about yet
        uploadLocalFlights(uid: uid)
    }

    private func stopListener() {
        listener?.remove()
        listener   = nil
        currentUID = nil
    }

    private func userFlights(uid: String) -> CollectionReference {
        db.collection("users").document(uid).collection("flights")
    }

    // MARK: - Private: SwiftData upsert

    private func upsert(doc: QueryDocumentSnapshot) {
        guard
            let ctx  = modelContext,
            let uuid = UUID(uuidString: doc.documentID)
        else { return }

        let data = doc.data()
        guard
            let originIATA      = data["originIATA"]      as? String,
            let destinationIATA = data["destinationIATA"] as? String,
            let ts              = data["date"]             as? Timestamp,
            let distanceKm      = data["distanceKm"]      as? Double
        else { return }

        let date = ts.dateValue()
        let descriptor = FetchDescriptor<Flight>(predicate: #Predicate { $0.id == uuid })

        if let existing = try? ctx.fetch(descriptor).first {
            existing.originIATA      = originIATA
            existing.destinationIATA = destinationIATA
            existing.date            = date
            existing.distanceKm      = distanceKm
            existing.seatType        = (data["seatType"]    as? String).flatMap(SeatType.init)
            existing.flightClass     = (data["flightClass"] as? String).flatMap(FlightClass.init)
            existing.airline         = data["airline"]      as? String
            existing.flightNumber    = data["flightNumber"] as? String
            existing.aircraftType    = data["aircraftType"] as? String
        } else {
            let flight = Flight(
                originIATA:      originIATA,
                destinationIATA: destinationIATA,
                date:            date,
                distanceKm:      distanceKm,
                seatType:        (data["seatType"]    as? String).flatMap(SeatType.init),
                flightClass:     (data["flightClass"] as? String).flatMap(FlightClass.init),
                airline:         data["airline"]      as? String,
                aircraftType:    data["aircraftType"] as? String,
                flightNumber:    data["flightNumber"] as? String
            )
            flight.id = uuid   // preserve original UUID so future syncs match correctly
            ctx.insert(flight)
        }
    }

    private func deleteLocal(idString: String) {
        guard
            let ctx  = modelContext,
            let uuid = UUID(uuidString: idString)
        else { return }
        let descriptor = FetchDescriptor<Flight>(predicate: #Predicate { $0.id == uuid })
        if let flight = try? ctx.fetch(descriptor).first {
            ctx.delete(flight)
        }
    }

    /// On first sync, push all local flights so Firestore has a complete copy.
    private func uploadLocalFlights(uid: String) {
        guard let ctx = modelContext else { return }
        guard let flights = try? ctx.fetch(FetchDescriptor<Flight>()) else { return }
        for flight in flights { push(flight) }
    }
}
