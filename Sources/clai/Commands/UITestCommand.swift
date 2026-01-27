import ArgumentParser
import Foundation

struct UITestCommand: AsyncParsableCommand {
    static let configuration = CommandConfiguration(
        commandName: "ui-test",
        abstract: "Test UI rendering (Internal)"
    )

    func run() async throws {
        let terminal = TerminalUI(verbose: false)
        let markdown = """
        # Table Test

        Here is a table:

        | Name | Role | Description |
        | :--- | :---: | ---: |
        | **Alice** | Developer | _Frontend_ |
        | Bob | `Manager` | Backend |
        | Charlie | QA | Fullstack |

        End of table.

        ## Another Table (Plain)
        | A | B |
        |---|---|
        | 1 | 2 |
        """
        terminal.showResponse(markdown, format: .plain)
    }
}
