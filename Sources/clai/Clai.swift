import ArgumentParser
import Foundation

@main
struct Clai: AsyncParsableCommand {
    static let configuration = CommandConfiguration(
        commandName: "clai",
        abstract: "LLM-powered CLI help assistant",
        discussion: """
        AI-powered CLI assistant that explains commands, suggests solutions, \
        and provides examples.

        USAGE:
          clai <command>            Explain a command (e.g., clai git rebase)
          clai suggest "<task>"     Find commands for a task
          clai examples <command>   Show practical examples
          clai man <command>        Summarize man page
          clai cache stats|clear    View or clear response cache

        PROVIDERS (in priority order):
          1. MLX       Local inference on Apple Silicon
          2. Ollama    Local inference server
          3. Anthropic Claude API (requires ANTHROPIC_API_KEY)
          4. OpenAI    GPT API (requires OPENAI_API_KEY)

        OPTIONS:
          --provider <name>   Force specific provider (mlx, ollama, anthropic, openai)
          --no-cache          Skip response cache
          --no-stream         Disable streaming output
          --json              Output as JSON
        """,
        version: "v1.0.5",
        subcommands: [
            ExplainCommand.self,
            SuggestCommand.self,
            ExamplesCommand.self,
            ManCommand.self,
            CacheCommand.self,
            SetupCommand.self,
            CompletionsCommand.self,
            ModelsCommand.self,
        ],
        defaultSubcommand: ExplainCommand.self
    )
}
