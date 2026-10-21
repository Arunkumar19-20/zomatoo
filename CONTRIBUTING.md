# Contributing to Cravey

Thank you for your interest in contributing to Cravey! Whether fixing bugs, improving docs, or proposing new features, all contributions are welcome.

## Code of Conduct
Please maintain a respectful and welcoming environment for everyone in discussions, issue comments, and code reviews.

## Development Workflow

1. **Fork and Clone**:
   ```bash
   git clone https://github.com/<your-username>/cravey.git
   cd cravey
   ```
2. **Create a Feature Branch**:
   ```bash
   git checkout -b feature/your-feature-name
   ```
3. **Run Checks Locally**:
   - **Frontend**:
     ```bash
     dart analyze
     flutter test
     ```
   - **Backend**:
     ```bash
     cd backend
     ./mvnw clean test
     ```
4. **Commit & Push**:
   Write clear, conventional commit messages (`feat: ...`, `fix: ...`, `refactor: ...`, `test: ...`).
5. **Open a Pull Request**:
   Describe your changes, test evidence, and any linked issues. Ensure GitHub CI checks pass.

## Reporting Issues
If you encounter a bug or have a feature suggestion, please open an issue on GitHub with steps to reproduce and system details.
