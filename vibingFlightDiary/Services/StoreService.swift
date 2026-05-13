import Foundation
import StoreKit

@Observable
final class StoreService {

    // MARK: - Product IDs

    static let premiumMonthlyID = "io.flown.app.premium.monthly"

    /// Set to false to disable the paywall and hide premium UI (v1 launch mode)
    static let premiumEnabled = false

    // MARK: - Published State

    private(set) var isPremium = false
    private(set) var monthlyProduct: Product?
    private(set) var isLoading = false
    private(set) var purchaseError: String?

    // MARK: - Private

    private var updateTask: Task<Void, Never>?

    // MARK: - Lifecycle

    init() {
        updateTask = listenForTransactions()
        Task { await loadProducts() }
        Task { await checkEntitlements() }
    }

    deinit {
        updateTask?.cancel()
    }

    // MARK: - Load Products

    func loadProducts() async {
        do {
            let products = try await Product.products(for: [Self.premiumMonthlyID])
            monthlyProduct = products.first
        } catch {
            print("[StoreService] Failed to load products: \(error)")
        }
    }

    // MARK: - Purchase

    @MainActor
    func purchase() async {
        guard let product = monthlyProduct else {
            purchaseError = "Product not available"
            return
        }
        isLoading = true
        purchaseError = nil

        do {
            let result = try await product.purchase()
            switch result {
            case .success(let verification):
                let transaction = try checkVerified(verification)
                await transaction.finish()
                await checkEntitlements()
            case .userCancelled:
                break
            case .pending:
                break
            @unknown default:
                break
            }
        } catch {
            purchaseError = error.localizedDescription
        }

        isLoading = false
    }

    // MARK: - Restore

    @MainActor
    func restore() async {
        isLoading = true
        try? await AppStore.sync()
        await checkEntitlements()
        isLoading = false
    }

    // MARK: - Check Entitlements

    func checkEntitlements() async {
        var hasPremium = false
        for await result in Transaction.currentEntitlements {
            if let transaction = try? checkVerified(result),
               transaction.productID == Self.premiumMonthlyID,
               transaction.revocationDate == nil {
                hasPremium = true
                break
            }
        }
        await MainActor.run { isPremium = hasPremium }
    }

    // MARK: - Transaction Listener

    private func listenForTransactions() -> Task<Void, Never> {
        Task.detached { [weak self] in
            for await result in Transaction.updates {
                if let transaction = try? self?.checkVerified(result) {
                    await transaction.finish()
                    await self?.checkEntitlements()
                }
            }
        }
    }

    // MARK: - Verification

    private func checkVerified<T>(_ result: VerificationResult<T>) throws -> T {
        switch result {
        case .unverified(_, let error): throw error
        case .verified(let value):      return value
        }
    }

    // MARK: - Free Tier Limit

    static let freeFlightLimit = 20
}
