# Contributing to Hecate Plugin SDK

Thank you for your interest in contributing!

## Getting Started

1. Fork the repository
2. Clone your fork: `git clone https://github.com/YOUR_USER/hecate-sdk.git`
3. Install dependencies: `rebar3 get-deps`
4. Run tests: `rebar3 eunit`
5. Build docs: `rebar3 ex_doc`

## Development

### Prerequisites

- Erlang/OTP 27+
- rebar3

### Running Tests

```bash
rebar3 eunit
```

### Building Documentation

```bash
rebar3 ex_doc
# Open doc/index.html in your browser
```

### Code Style

- Follow standard Erlang conventions
- All exported functions must have `@doc` and `-spec`
- No `@doc` on `-callback` declarations (EDoc limitation)
- No backticks, `@param`, `@returns`, or `@see` with URLs in EDoc comments
- Run `rebar3 dialyzer` before submitting

## Submitting Changes

1. Create a feature branch: `git checkout -b my-feature`
2. Make your changes
3. Add tests for new functionality
4. Ensure all tests pass: `rebar3 eunit`
5. Ensure docs build cleanly: `rebar3 ex_doc`
6. Commit with a descriptive message
7. Push and create a pull request

## Reporting Issues

Open an issue at https://github.com/hecate-social/hecate-sdk/issues with:

- SDK version
- Erlang/OTP version
- Steps to reproduce
- Expected vs actual behavior

## License

By contributing, you agree that your contributions will be licensed under the Apache-2.0 license.
