import AppKit

let path = URL(fileURLWithPath: CommandLine.arguments[1]).standardizedFileURL
let applications = NSWorkspace.shared.runningApplications.filter { $0.bundleURL?.standardizedFileURL == path }
for application in applications {
    guard application.terminate() else {
        fputs("Window Organizer could not quit. Finish any active operation and retry.\n", stderr)
        exit(1)
    }
}
let deadline = Date().addingTimeInterval(10)
while applications.contains(where: { !$0.isTerminated }) && Date() < deadline {
    RunLoop.current.run(until: Date().addingTimeInterval(0.1))
}
guard applications.allSatisfy({ $0.isTerminated }) else {
    fputs("Window Organizer has not quit; the update was stopped without force-quitting it.\n", stderr)
    exit(1)
}
