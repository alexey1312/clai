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
          clai chat                 Start interactive chat session
          clai recall "<query>"     Search history with natural language
          clai improve "<command>"  Get optimization suggestions
          clai history              Manage history index
          clai cache stats|clear    View or clear response cache
          clai completions install  Install shell plugin with AI hotkeys
          clai daemon start         Start background daemon for fast responses

        SHELL INTEGRATION:
          Install plugin: clai completions install zsh
          Hotkeys: Ctrl+X Ctrl+E (explain), Ctrl+X Ctrl+S (suggest)

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
        version: "v1.1.2",
        subcommands: [
            ExplainCommand.self,
            SuggestCommand.self,
            ExamplesCommand.self,
            ManCommand.self,
            ChatCommand.self,
            RecallCommand.self,
            ImproveCommand.self,
            HistoryCommand.self,
            CacheCommand.self,
            SetupCommand.self,
            CompletionsCommand.self,
            DaemonCommand.self,
            ModelsCommand.self,
            DocsCommand.self,
            ManPageGenCommand.self,
            UITestCommand.self,
        ],
        defaultSubcommand: ExplainCommand.self
    )
}
