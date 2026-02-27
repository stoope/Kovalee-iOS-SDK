#if canImport(AdjustSdk)
    import AdjustSdk
#endif
import AdSupport
import AppTrackingTransparency
import Foundation
import KovaleeFramework
import KovaleeSDK

extension AdjustConfiguration.Environment {
    var adjustEnvironment: String {
        #if canImport(AdjustSdk)
            switch self {
            case .production:
                return ADJEnvironmentProduction
            default:
                return ADJEnvironmentSandbox
            }
        #else
            return ""
        #endif
    }
}

public extension AdjustConfiguration {
    static var test: Self {
        Self(environment: "test", token: "")
    }
}

final class AdjustWrapperImpl: NSObject, AttributionManager, Manager {
    init(
        configuration: AdjustConfiguration,
        attributionAdidCallback: @escaping @Sendable (String?) -> Void
    ) {
        KLogger.debug("initializing Adjust")

        self.attributionAdidCallback = attributionAdidCallback
        self.configuration = configuration
        super.init()

    #if canImport(AdjustSdk)
            let adjustConfig = ADJConfig(
                appToken: configuration.token,
                environment: configuration.environment.adjustEnvironment
            )
            adjustConfig?.logLevel = KLogger.logLevel.adjustLogLevel()
            adjustConfig?.attConsentWaitingInterval = 3
            adjustConfig?.delegate = self

            Adjust.initSdk(adjustConfig)
    #endif
    }

    func setDataCollectionEnabled(_ enabled: Bool) {
    #if canImport(AdjustSdk)
            guard let value = ADJThirdPartySharing(isEnabled: enabled ? 1 : 0) else {
                return
            }
            Adjust.trackThirdPartySharing(value)
    #endif
    }

    func getAttributionAdid() async -> String? {
    #if canImport(AdjustSdk)
            await Adjust.adid()
    #endif
    }

    func promptTrackingAuthorization(completion: @escaping (ATTrackingManager.AuthorizationStatus) -> Void) {
    #if canImport(AdjustSdk)
            Adjust.requestAppTrackingAuthorization { _ in
                completion(ATTrackingManager.trackingAuthorizationStatus)
            }
    #else
            ATTrackingManager.requestTrackingAuthorization(completionHandler: completion)
    #endif
    }

    func sendConversionValue(value: Int, coarseValue: String?, completion: @escaping (Error?) -> Void) {
        #if canImport(AdjustSdk)
            Adjust.updateSkanConversionValue(value, coarseValue: coarseValue, lockWindow: false) { error in
                completion(error)
            }
        #endif
    }

    func setAttributionDelegate(_ delegate: KovaleeFramework.KovaleeAttributionDelegate) {
        self.delegate = delegate
    }

    let attributionAdidCallback: @Sendable (String?) -> Void
    let configuration: AdjustConfiguration

    private var delegate: KovaleeFramework.KovaleeAttributionDelegate?
}

extension AdjustWrapperImpl: @unchecked Sendable {}

#if canImport(AdjustSdk)
    extension AdjustWrapperImpl: AdjustDelegate {
        func adjustSessionTrackingSucceeded(_ session: ADJSessionSuccess?) {
            attributionAdidCallback(session?.adid)
        }

        func adjustConversionValueUpdated(_ fineValue: NSNumber?, coarseValue _: String?, lockWindow _: NSNumber?) {
            KLogger.debug("Successfully Updated Conversion Value: \(String(describing: fineValue))")
        }

        func adjustDeferredDeeplinkReceived(_ deeplink: URL?) -> Bool {
            delegate?.adjustDeferredDeeplinkReceived(deeplink) ?? true
        }
    }
#endif

extension AttributionManager {
    static var test: AttributionManager {
        AdjustWrapperImpl(
            configuration: .test,
            attributionAdidCallback: { _ in }
        )
    }
}

#if canImport(AdjustSdk)
    extension KovaleeFramework.LogLevel {
        func adjustLogLevel() -> ADJLogLevel {
            switch self {
            case .verbose:
                .verbose
            case .debug:
                .debug
            case .info:
                .info
            case .warn:
                .warn
            case .error:
                .error
            @unknown default:
                fatalError()
            }
        }
    }
#endif
