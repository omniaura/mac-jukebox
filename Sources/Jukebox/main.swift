import Foundation

let version = ProcessInfo.processInfo.environment["JUKEBOX_VERSION"] ?? "0.0.0-dev"

// Launched from Finder/`open` there are no arguments and no terminal: be the menu bar app.
// From a shell, no arguments prints help.
if CommandLine.arguments.count == 1, isatty(STDIN_FILENO) == 0 {
    runApp()
}
runCLI(Array(CommandLine.arguments.dropFirst()))
