import Foundation
import Darwin

@main
struct PuffCLI {
    static func main() {
        let cli = PuffCommand(arguments: Array(CommandLine.arguments.dropFirst()))
        do {
            try cli.run()
        } catch {
            fputs("Error: \(error.localizedDescription)\n", stderr)
            exit(EXIT_FAILURE)
        }
    }
}

struct PuffCommand {
    private let arguments: [String]
    private let fileManager = FileManager.default

    init(arguments: [String]) {
        self.arguments = arguments
    }

    func run() throws {
        let parsed = try parseArguments()

        if parsed.showHelp {
            printHelp()
            exit(EXIT_SUCCESS)
        }

        guard let assistantName = parsed.assistantName else {
            throw CLIError.usage
        }

        guard let helperAppURL = resolveHelperAppURL() else {
            throw CLIError.helperNotFound
        }

        let helperBinary = helperAppURL
            .appendingPathComponent("Contents", isDirectory: true)
            .appendingPathComponent("MacOS", isDirectory: true)
            .appendingPathComponent("puff-helper", isDirectory: false)

        guard fileManager.isExecutableFile(atPath: helperBinary.path) else {
            throw CLIError.helperNotExecutable(helperBinary.path)
        }

        try launchHelper(at: helperBinary, arguments: [assistantName])
    }

    private func parseArguments() throws -> (assistantName: String?, showHelp: Bool) {
        var assistantName: String?
        var showHelp = false

        for argument in arguments {
            switch argument {
            case "--help", "-h":
                showHelp = true
            default:
                if assistantName == nil {
                    assistantName = argument
                } else {
                    throw CLIError.tooManyArguments
                }
            }
        }

        return (assistantName, showHelp)
    }

    private func resolveHelperAppURL() -> URL? {
        if let envPath = ProcessInfo.processInfo.environment["PUFF_HELPER_PATH"] {
            let url = URL(fileURLWithPath: envPath).resolvingSymlinksInPath()
            if fileManager.fileExists(atPath: url.path) {
                return url
            }
        }

        let cliURL = currentExecutableURL()
        let binDirectory = cliURL.deletingLastPathComponent()

        for directory in directoriesToProbe(startingAt: binDirectory) {
            let direct = directory.appendingPathComponent("Puff.app", isDirectory: true)
            if fileManager.fileExists(atPath: direct.path) {
                return direct
            }

            let libexec = directory
                .appendingPathComponent("libexec", isDirectory: true)
                .appendingPathComponent("Puff.app", isDirectory: true)
            if fileManager.fileExists(atPath: libexec.path) {
                return libexec
            }
        }

        return nil
    }

    private func currentExecutableURL() -> URL {
        var size = UInt32(PATH_MAX)
        var buffer = [Int8](repeating: 0, count: Int(size))
        var result = _NSGetExecutablePath(&buffer, &size)

        if result != 0 {
            buffer = [Int8](repeating: 0, count: Int(size))
            result = _NSGetExecutablePath(&buffer, &size)
        }

        let path = buffer.withUnsafeBufferPointer {
            $0.baseAddress.map { String(cString: $0) } ?? CommandLine.arguments[0]
        }

        return URL(fileURLWithPath: path).resolvingSymlinksInPath()
    }

    private func directoriesToProbe(startingAt directory: URL) -> [URL] {
        var results: [URL] = []
        var current = directory
        let maxDepth = 4

        for _ in 0..<maxDepth {
            results.append(current)
            let parent = current.deletingLastPathComponent()
            if parent.path == current.path {
                break
            }
            current = parent
        }

        return results
    }

    private func launchHelper(at binaryURL: URL, arguments: [String]) throws {
        let process = Process()
        process.executableURL = binaryURL
        process.arguments = arguments
        process.standardOutput = FileHandle.standardOutput
        process.standardError = FileHandle.standardError

        do {
            try process.run()
            process.waitUntilExit()
            
            if process.terminationStatus != 0 {
                throw CLIError.helperLaunchFailed(
                    NSError(
                        domain: "PuffCLI",
                        code: Int(process.terminationStatus),
                        userInfo: [NSLocalizedDescriptionKey: "Helper exited with status \(process.terminationStatus)"]
                    )
                )
            }
            
            exit(EXIT_SUCCESS)
        } catch {
            throw CLIError.helperLaunchFailed(error)
        }
    }

    private func printHelp() {
        let text = """
        Usage: puff <assistant-name>

        Options:
          -h, --help        Show this help text and exit

        Examples:
          puff AssistantA
        """
        print(text)
    }

    enum CLIError: LocalizedError {
        case usage
        case helperNotFound
        case helperNotExecutable(String)
        case helperLaunchFailed(Error)
        case tooManyArguments

        var errorDescription: String? {
            switch self {
            case .usage:
                return "Usage: puff <assistant-name>"
            case .helperNotFound:
                return "Puff.app not found next to the CLI. Run Scripts/build_and_bundle.sh and keep Puff.app alongside the puff binary."
            case .helperNotExecutable(let path):
                return "Helper binary at \(path) is missing or not executable."
            case .helperLaunchFailed(let error):
                return "Failed to launch helper app: \(error.localizedDescription)"
            case .tooManyArguments:
                return "Only one assistant name is supported. See puff --help."
            }
        }
    }
}
