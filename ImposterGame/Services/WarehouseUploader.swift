import Foundation
import StoreKit
import UIKit

/// Sends the rows only the device knows - install, Apple Ads attribution, originalTransactionId -
/// to the BigQuery warehouse through the `ingest` Cloud Function (analytics/functions).
///
/// Every row goes into a queue in UserDefaults first and leaves it only once the function accepted
/// it, so an offline first launch or a function outage delays a row instead of losing it.
enum WarehouseUploader {
    static func start() {
        Task.detached(priority: .utility) {
            await Queue.shared.enqueueInstallIfNeeded()
            // Attribution resolved by a build that had no uploader yet.
            if let payload = UserDefaults.standard.data(forKey: SearchAdsAttributionService.payloadKey) {
                await Queue.shared.enqueueAttribution(payload, onlyOnce: true)
            }
            await Queue.shared.enqueueTransactionMap()
            await Queue.shared.flush()
        }
    }

    /// Raw AdServices response, exactly as Apple returned it.
    static func sendAttribution(_ payload: Data) {
        Task.detached(priority: .utility) {
            await Queue.shared.enqueueAttribution(payload, onlyOnce: false)
            await Queue.shared.flush()
        }
    }

    private actor Queue {
        static let shared = Queue()

        private static let endpoint = URL(string: "https://us-central1-imposter-who-s-the-spy.cloudfunctions.net/ingest")!
        private static let queueKey = "warehouseUploadQueue"
        private static let installQueuedKey = "warehouseInstallQueued"
        private static let attributionQueuedKey = "warehouseAttributionQueued"
        private static let sentTransactionsKey = "warehouseSentOriginalTransactionIds"
        /// A device that can't reach the function for months shouldn't grow UserDefaults forever.
        private static let maxJobs = 50

        private struct Job: Codable {
            let path: String
            let body: Data
        }

        private let defaults = UserDefaults.standard
        private var isFlushing = false

        func enqueueInstallIfNeeded() async {
            guard !defaults.bool(forKey: Self.installQueuedKey) else { return }
            let idfv = await MainActor.run { UIDevice.current.identifierForVendor?.uuidString }
            enqueue("app/install", [
                "user_id": UserIdentity.id,
                "installed_at": Self.iso(Self.installDate()),
                "storefront": await Storefront.current?.countryCode,
                "locale": Locale.current.identifier,
                "idfv": idfv,
                "app_version": Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String
            ])
            defaults.set(true, forKey: Self.installQueuedKey)
        }

        func enqueueAttribution(_ payload: Data, onlyOnce: Bool) {
            if onlyOnce && defaults.bool(forKey: Self.attributionQueuedKey) { return }
            guard let raw = try? JSONSerialization.jsonObject(with: payload) else { return }
            enqueue("app/attribution", ["user_id": UserIdentity.id, "raw": raw])
            defaults.set(true, forKey: Self.attributionQueuedKey)
        }

        /// Subscribers who bought before `appAccountToken` existed: Apple's notifications for them
        /// carry no user id, so the warehouse maps their originalTransactionId to ours instead.
        func enqueueTransactionMap() async {
            var sent = Set(defaults.stringArray(forKey: Self.sentTransactionsKey) ?? [])
            var fresh: [String] = []
            for await result in Transaction.currentEntitlements {
                guard case .verified(let transaction) = result else { continue }
                let id = String(transaction.originalID)
                if !sent.contains(id) { fresh.append(id) }
            }
            guard !fresh.isEmpty else { return }
            enqueue("app/txmap", ["user_id": UserIdentity.id, "original_transaction_ids": fresh])
            sent.formUnion(fresh)
            defaults.set(Array(sent), forKey: Self.sentTransactionsKey)
        }

        func flush() async {
            guard !isFlushing else { return }
            isFlushing = true
            defer { isFlushing = false }

            while let job = jobs().first {
                var request = URLRequest(url: Self.endpoint.appendingPathComponent(job.path))
                request.httpMethod = "POST"
                request.setValue("application/json", forHTTPHeaderField: "Content-Type")
                request.httpBody = job.body
                request.timeoutInterval = 20

                guard let (_, response) = try? await URLSession.shared.data(for: request),
                      let status = (response as? HTTPURLResponse)?.statusCode else { return }
                // 5xx / 408 / 429: the function is unwell - keep the job for the next launch.
                // Any other 4xx is a payload the function will never accept, so drop it.
                if status >= 500 || status == 408 || status == 429 { return }
                save(Array(jobs().dropFirst()))
            }
        }

        private func enqueue(_ path: String, _ body: [String: Any?]) {
            guard let data = try? JSONSerialization.data(withJSONObject: body.compactMapValues { $0 }) else { return }
            save(Array((jobs() + [Job(path: path, body: data)]).suffix(Self.maxJobs)))
        }

        private func jobs() -> [Job] {
            guard let data = defaults.data(forKey: Self.queueKey) else { return [] }
            return (try? JSONDecoder().decode([Job].self, from: data)) ?? []
        }

        private func save(_ jobs: [Job]) {
            defaults.set(try? JSONEncoder().encode(jobs), forKey: Self.queueKey)
        }

        /// The Documents folder is created on first launch and survives app updates, so for users
        /// who installed before this build it still gives the real install date, not today.
        private static func installDate() -> Date {
            let documents = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first
            let created = documents.flatMap {
                try? FileManager.default.attributesOfItem(atPath: $0.path)[.creationDate] as? Date
            }
            return created ?? Date()
        }

        private static func iso(_ date: Date) -> String {
            ISO8601DateFormatter().string(from: date)
        }
    }
}
