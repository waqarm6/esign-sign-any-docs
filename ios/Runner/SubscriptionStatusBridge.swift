import Flutter
import StoreKit

/// Exposes StoreKit 2's verified current entitlement state to Flutter.
final class SubscriptionStatusBridge {
    private static let channelName = "esign_doc_pro/subscription_status"
    private static let subscriptionProductIDs: Set<String> = [
        "esign_doc_pro_weekly",
        "esign_doc_pro_monthly",
        "esign_doc_pro_yearly"
    ]

    static func register(with registrar: FlutterPluginRegistrar) {
        let channel = FlutterMethodChannel(
            name: channelName,
            binaryMessenger: registrar.messenger()
        )
        channel.setMethodCallHandler { call, result in
            guard call.method == "hasActiveEntitlement" else {
                result(FlutterMethodNotImplemented)
                return
            }

            Task {
                let active = await hasActiveEntitlement()
                await MainActor.run { result(active) }
            }
        }
    }

    @available(iOS 15.0, *)
    private static func verifiedEntitlementExists() async -> Bool {
        for await entitlement in Transaction.currentEntitlements {
            guard case .verified(let transaction) = entitlement else { continue }
            guard subscriptionProductIDs.contains(transaction.productID) else { continue }
            guard transaction.revocationDate == nil else { continue }
            return true
        }
        return false
    }

    private static func hasActiveEntitlement() async -> Bool {
        guard #available(iOS 15.0, *) else { return false }
        return await verifiedEntitlementExists()
    }
}
