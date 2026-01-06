## 2024-05-24 - Interactive CLI Error Handling
**Learning:** In interactive CLI prompts, users often make typos. Aborting on invalid input (instead of retrying) frustrates users and forces them to restart the entire command flow.
**Action:** Always wrap interactive selection prompts in a loop that validates input, provides clear error feedback (e.g., in red), and allows retrying, while still offering a way to cancel (e.g., EOF or empty line).
