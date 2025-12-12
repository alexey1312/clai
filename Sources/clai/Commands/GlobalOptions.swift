import ArgumentParser

struct GlobalOptions: ParsableArguments {
    @Option(name: .long, help: "Force specific provider (foundation, mlx, ollama, anthropic, openai)")
    var provider: Provider?

    @Flag(name: .long, help: "Output as JSON for scripting")
    var json = false

    @Flag(name: .long, help: "Show detailed diagnostic output")
    var verbose = false

    @Flag(name: .long, help: "Bypass response cache")
    var noCache = false

    @Flag(name: .long, inversion: .prefixedNo, help: "Stream response tokens as they arrive")
    var stream = true
}

enum Provider: String, ExpressibleByArgument, CaseIterable {
    case foundation
    case mlx
    case ollama
    case anthropic
    case openai
}
