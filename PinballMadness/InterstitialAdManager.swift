import GoogleMobileAds
import UIKit

final class InterstitialAdManager: NSObject, FullScreenContentDelegate {
    static let shared = InterstitialAdManager()

    var onWillPresent: (() -> Void)?
    var onDidDismiss: (() -> Void)?

    private var ad: InterstitialAd?
    private var isLoading = false
    private(set) var isPresenting = false

    // iOS interstitial test ID:
    // "ca-app-pub-3940256099942544/4411468910"
    // actual:
    // "ca-app-pub-6417321048011372~8770071026"
    private let adUnitID = "ca-app-pub-3940256099942544/4411468910"

    func load() {
        guard !isLoading, ad == nil else { return }
        isLoading = true
        InterstitialAd.load(with: adUnitID, request: Request()) { [weak self] ad, error in
            guard let self else { return }
            self.isLoading = false
            if let error = error {
                print("Interstitial load failed: \(error.localizedDescription)")
                DispatchQueue.main.asyncAfter(deadline: .now() + 6) { self.load() }
                return
            }
            self.ad = ad
            self.ad?.fullScreenContentDelegate = self
        }
    }

    @discardableResult
    func present(from root: UIViewController?) -> Bool {
        guard let root, let ad = ad else { return false }
        isPresenting = true
        onWillPresent?()
        ad.present(from: root)
        return true
    }

    func adWillPresentFullScreenContent(_ ad: FullScreenPresentingAd) {
        isPresenting = true
        onWillPresent?()
    }

    func adDidDismissFullScreenContent(_ ad: FullScreenPresentingAd) {
        isPresenting = false
        onDidDismiss?()
        self.ad = nil
        load()
    }

    func ad(_ ad: FullScreenPresentingAd,
            didFailToPresentFullScreenContentWithError error: Error) {
        isPresenting = false
        onDidDismiss?()
        self.ad = nil
        load()
    }
}

func topViewController(base: UIViewController? = {
    UIApplication.shared.connectedScenes
        .compactMap { $0 as? UIWindowScene }
        .flatMap { $0.windows }
        .first { $0.isKeyWindow }?.rootViewController
}()) -> UIViewController? {
    if let nav = base as? UINavigationController {
        return topViewController(base: nav.visibleViewController)
    }
    if let tab = base as? UITabBarController {
        return topViewController(base: tab.selectedViewController)
    }
    if let presented = base?.presentedViewController {
        return topViewController(base: presented)
    }
    return base
}
