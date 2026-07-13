# Contributing

Thanks for your interest in improving this blueprint! Contributions of all
sizes — bug fixes, documentation, new deployment options — are welcome.

## Ways to contribute

- 🐛 **Report a bug** — open an issue describing what happened, what you
  expected, and how to reproduce it.
- 💡 **Suggest an improvement** — open an issue to discuss it first, especially
  for larger changes.
- 📖 **Improve the docs** — clearer instructions and fixed typos are always
  appreciated.
- 🔧 **Submit a fix** — see the workflow below.

## Development workflow

1. **Fork** the repository and create a feature branch:
   ```bash
   git checkout -b feat/short-description
   ```
2. **Run the stack locally** and confirm your change works
   (see [`docs/LOCAL_DEVELOPMENT.md`](docs/LOCAL_DEVELOPMENT.md)):
   ```bash
   docker compose up -d --build
   ```
3. **Keep documentation in sync.** No change is complete until the relevant
   docs (`README.md`, files under `docs/`, inline comments) reflect it.
4. **Commit** using clear, conventional messages:
   ```
   feat: add ElastiCache configuration example
   fix: correct FastCGI pass host in nginx config
   docs: clarify ECR login step
   ```
5. **Open a pull request** describing the change and the motivation behind it.

## Coding standards

- Keep the two-container separation (app / nginx) intact.
- Never hardcode AWS account IDs, credentials, or other secrets — use
  placeholders (`<AWS_ACCOUNT_ID>`, `<AWS_REGION>`) and CI/CD variables.
- Prefer least-privilege defaults (non-root user, minimal file permissions).
- Match the existing formatting in Dockerfiles, YAML, and Markdown.

## Reporting security issues

If you discover a security vulnerability, please **do not** open a public
issue. Instead, contact the maintainer directly so it can be addressed
responsibly.
