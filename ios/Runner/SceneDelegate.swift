import UIKit

class SceneDelegate: UIResponder, UIWindowSceneDelegate {
  var window: UIWindow?

  func scene(
    _ scene: UIScene,
    willConnectTo session: UISceneSession,
    options connectionOptions: UIScene.ConnectionOptions
  ) {
    // Storyboard-based scene setup is handled by UIApplicationSceneManifest.
    guard (scene as? UIWindowScene) != nil else { return }
  }
}
