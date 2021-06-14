import UIKit
import MediaPlayer

@UIApplicationMain
class AppDelegate: UIResponder, UIApplicationDelegate {
    
    static let name = "Amperfy"
    static var version: String {
        return (Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String) ?? ""
    }
    static var buildNumber: String {
        return (Bundle.main.object(forInfoDictionaryKey: "CFBundleVersion") as? String) ?? ""
    }
    
    var window: UIWindow?

    lazy var persistentStorage = {
        return PersistentStorage()
    }()
    lazy var library = {
        return LibraryStorage(context: persistentStorage.context)
    }()
    lazy var eventLogger = {
        return EventLogger(alertDisplayer: self, persistentContainer: persistentStorage.persistentContainer)
    }()
    lazy var backendProxy: BackendProxy = {
        return BackendProxy(eventLogger: eventLogger)
    }()
    lazy var backendApi: BackendApi = {
        return backendProxy
    }()
    lazy var player: MusicPlayer = {
        let backendAudioPlayer = BackendAudioPlayer(mediaPlayer: AVPlayer(), eventLogger: eventLogger, backendApi: backendApi, songDownloader: songDownloadManager, songCache: library, userStatistics: userStatistics)
        return MusicPlayer(coreData: library.getPlayerData(), songDownloadManager: songDownloadManager, backendAudioPlayer: backendAudioPlayer, userStatistics: userStatistics)
    }()
    lazy var songDownloadManager: DownloadManager = {
        let requestManager = RequestManager()
        let dlDelegate = SongDownloadDelegate(backendApi: backendApi)
        let urlDownloader = UrlDownloader(requestManager: requestManager)
        let dlManager = DownloadManager(persistentStorage: persistentStorage, requestManager: requestManager, urlDownloader: urlDownloader, downloadDelegate: dlDelegate, eventLogger: eventLogger)
        urlDownloader.urlDownloadNotifier = dlManager
        return dlManager
    }()
    lazy var artworkDownloadManager: DownloadManager = {
        let requestManager = RequestManager()
        let dlDelegate = backendApi.createArtworkArtworkDownloadDelegate()
        let urlDownloader = UrlDownloader(requestManager: requestManager)
        let dlManager = DownloadManager(persistentStorage: persistentStorage, requestManager: requestManager, urlDownloader: urlDownloader, downloadDelegate: dlDelegate, eventLogger: eventLogger)
        urlDownloader.urlDownloadNotifier = dlManager
        return dlManager
    }()
    lazy var backgroundSyncerManager = {
        return BackgroundSyncerManager(persistentStorage: persistentStorage, backendApi: backendApi)
    }()
    lazy var userStatistics = {
        return library.getUserStatistics(appVersion: Self.version)
    }()

    func reinit() {
        player.reinit(coreData: library.getPlayerData())
    }

    func configureAudioSessionInterruptionAndRemoteControl() {
        self.player.configureObserverForAudioSessionInterruption(audioSession: AVAudioSession.sharedInstance())
        self.player.configureBackgroundPlayback(audioSession: AVAudioSession.sharedInstance())
        UIApplication.shared.beginReceivingRemoteControlEvents()
        self.player.nowPlayingInfoCenter = MPNowPlayingInfoCenter.default()
        self.player.configureRemoteCommands(commandCenter: MPRemoteCommandCenter.shared())
    }
    
    var isKeepScreenAlive: Bool {
        get { return UIApplication.shared.isIdleTimerDisabled }
        set { UIApplication.shared.isIdleTimerDisabled = newValue }
    }
    
    func configureDefaultNavigationBarStyle() {
        UINavigationBar.appearance().shadowImage = UIImage()
    }

    func application(_ application: UIApplication, didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?) -> Bool {
        configureAudioSessionInterruptionAndRemoteControl()
        configureDefaultNavigationBarStyle()
        self.window = UIWindow(frame: UIScreen.main.bounds)
        
        guard let credentials = persistentStorage.loginCredentials else {
            let initialViewController = LoginVC.instantiateFromAppStoryboard()
            self.window?.rootViewController = initialViewController
            self.window?.makeKeyAndVisible()
            return true
        }
        backendProxy.selectedApi = credentials.backendApi
        backendApi.provideCredentials(credentials: credentials)
        
        guard persistentStorage.isLibrarySynced else {
            let initialViewController = SyncVC.instantiateFromAppStoryboard()
            self.window?.rootViewController = initialViewController
            self.window?.makeKeyAndVisible()
            return true
        }
        backgroundSyncerManager.performBlockingLibraryUpdatesIfNeeded()
        backgroundSyncerManager.start()
        artworkDownloadManager.start()
        songDownloadManager.start()
        userStatistics.sessionStarted()
        let initialViewController = TabBarVC.instantiateFromAppStoryboard()
        self.window?.rootViewController = initialViewController
        self.window?.makeKeyAndVisible()
        return true
    }

    func applicationWillResignActive(_ application: UIApplication) {
        // Sent when the application is about to move from active to inactive state. This can occur for certain types of temporary interruptions (such as an incoming phone call or SMS message) or when the user quits the application and it begins the transition to the background state.
        // Use this method to pause ongoing tasks, disable timers, and invalidate graphics rendering callbacks. Games should use this method to pause the game.
    }

    func applicationDidEnterBackground(_ application: UIApplication) {
        // Use this method to release shared resources, save user data, invalidate timers, and store enough application state information to restore your application to its current state in case it is terminated later.
        // If your application supports background execution, this method is called instead of applicationWillTerminate: when the user quits.
        guard persistentStorage.loginCredentials != nil, persistentStorage.isLibrarySynced else { return }
        backgroundSyncerManager.stop()
    }

    func applicationWillEnterForeground(_ application: UIApplication) {
        // Called as part of the transition from the background to the active state; here you can undo many of the changes made on entering the background.
    }

    func applicationDidBecomeActive(_ application: UIApplication) {
        // Restart any tasks that were paused (or not yet started) while the application was inactive. If the application was previously in the background, optionally refresh the user interface.
        if persistentStorage.isLibrarySynced {
            backgroundSyncerManager.start()
        }
    }

    func applicationWillTerminate(_ application: UIApplication) {
        // Called when the application is about to terminate. Save data if appropriate. See also applicationDidEnterBackground:.
        if persistentStorage.loginCredentials != nil, persistentStorage.isLibrarySynced {
            artworkDownloadManager.stopAndWait()
            songDownloadManager.stopAndWait()
        }
        library.saveContext()
    }

}

extension AppDelegate {
    static func topViewController(base: UIViewController? = (UIApplication.shared.delegate as! AppDelegate).window?.rootViewController) -> UIViewController? {
        if base?.presentedViewController is UIAlertController {
            return base
        }
        if let nav = base as? UINavigationController {
            return topViewController(base: nav.visibleViewController)
        }
        if let tab = base as? UITabBarController, let selected = tab.selectedViewController {
            return topViewController(base: selected)
        }
        if let presented = base?.presentedViewController {
            return topViewController(base: presented)
        }
        return base
    }
}

extension AppDelegate: AlertDisplayable {
    func display(alert: UIAlertController) {
        guard let topView = Self.topViewController() else { return }
        alert.pruneNegativeWidthConstraintsToAvoidFalseConstraintWarnings()
        alert.setOptionsForIPadToDisplayPopupCentricIn(view: topView.view)
        topView.present(alert, animated: true, completion: nil)
    }
}
