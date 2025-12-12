import ArgumentParser
import Foundation

/// Command to generate shell completions
struct CompletionsCommand: ParsableCommand {
    static let configuration = CommandConfiguration(
        commandName: "completions",
        abstract: "Generate shell completion scripts",
        discussion: """
        Generate completion scripts for various shells.

        Installation:

        Zsh:
          clai completions zsh > ~/.zsh/completions/_clai
          # Add to .zshrc: fpath=(~/.zsh/completions $fpath)

        Bash:
          clai completions bash > /etc/bash_completion.d/clai
          # Or for user install:
          clai completions bash > ~/.local/share/bash-completion/completions/clai

        Fish:
          clai completions fish > ~/.config/fish/completions/clai.fish
        """
    )

    @Argument(help: "The shell to generate completions for (zsh, bash, fish)")
    var shell: Shell

    enum Shell: String, ExpressibleByArgument, CaseIterable {
        case zsh
        case bash
        case fish
    }

    func run() throws {
        let script: String = switch shell {
        case .zsh:
            Clai.completionScript(for: .zsh)
        case .bash:
            Clai.completionScript(for: .bash)
        case .fish:
            Clai.completionScript(for: .fish)
        }

        print(script)
    }
}
