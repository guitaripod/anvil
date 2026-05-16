import UIKit

@main
struct AnvilApp {
    static func main() {
        UIApplicationMain(
            CommandLine.argc,
            CommandLine.unsafeArgv,
            nil,
            NSStringFromClass(AppDelegate.self)
        )
    }
}
