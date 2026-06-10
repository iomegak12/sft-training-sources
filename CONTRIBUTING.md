# Contributing

Thanks for your interest in improving the Atlas Snowflake training labs!
These guidelines keep the lab assets consistent and reproducible for every
student.

## Ways to contribute

- Fix bugs in the data generator or Kafka producer
- Improve or clarify the SQL lab scripts
- Expand documentation ([README](README.md), [TROUBLESHOOTING](TROUBLESHOOTING.md))
- Add new labs or exercises

## Getting set up

```bash
git clone <repo-url>
cd sft-training-sources
uv sync
uv run python generate_market_data.py --quick   # smoke test
```

## Ground rules

1. **Keep data deterministic.** The generator uses a fixed seed so all students
   get identical data. If a change alters generated output, call it out clearly
   in your PR and update the [CHANGELOG](CHANGELOG.md).
2. **Never commit secrets.** No real Snowflake/AWS credentials, private keys, or
   account identifiers. Use placeholders (as the existing SQL scripts do) and
   keep them covered by [.gitignore](.gitignore).
3. **Keep labs ordered and self-consistent.** `Query-1.sql` … `Query-8.sql` are
   cumulative. If you add or reorder objects, make sure later scripts still run
   against the state earlier ones produce.
4. **Match existing style.** Follow the conventions already in the files —
   docstrings on Python entry points, uppercased SQL keywords/identifiers, and
   inline comments explaining *why* a step exists.

## Making changes

1. Create a branch off `main`:
   ```bash
   git checkout -b fix/short-description
   ```
2. Make your change and test it end-to-end:
   - Run `generate_market_data.py --quick` if you touched generation.
   - Run any affected SQL labs against a scratch Snowflake schema.
   - Bring up the Docker stack if you touched Lab 7.
3. Update docs and the [CHANGELOG](CHANGELOG.md) under an `Unreleased` heading.
4. Commit with a clear message and open a pull request describing:
   - What changed and why
   - Which labs are affected
   - Whether generated data output changes

## Reporting issues

Open an issue with:
- What you ran (command / script / lab number)
- What you expected vs. what happened
- Relevant error output (with secrets redacted)
- Your environment (OS, Python version, Snowflake edition, Docker version)

## Code of conduct

Be respectful and constructive. This is educational material — assume good faith
and aim to make the labs clearer for the next learner.
