# Agent Instructions

## Client Project

This project is a Flutter/Dart application. Treat `pubspec.yaml`,
`analysis_options.yaml`, and `.vscode/settings.json` as the source of truth for
tooling, linting, and formatting.

When changing client files:

- Work from this `client/` directory for Flutter and Dart commands.
- Format changed Dart files with `dart format`.
- Keep Dart formatting at the configured 80-character line length.
- Format Markdown description text, including commit message bodies, with
  Prettier before using it.
- When adding a file-level header comment, leave one empty line after it before
  imports or code.
- Run Flutter analysis after Dart changes: `flutter analyze`.
- For changes that affect runtime behavior or widgets, run the focused Flutter
  test or `flutter test` when practical.
- Keep JSON assets and configuration files formatted with the configured JSON
  formatter.

This emulates the Codium/VS Code setup:

- `editor.formatOnSave` is enabled.
- Dart uses the Dart-Code formatter.
- JSON uses the Prettier formatter.
- Save-time fix-all is configured through `editor.codeActionsOnSave`, so mimic
  it by applying appropriate Dart fixes when changing linted code.

## Database Structure

- Client-side data structures must mirror the database structure defined by the
  server SQL migrations in `../server/prisma/migrations/*.sql`.
- Mirror the server ID conventions: enum-like lookup rows use integer IDs, and
  app-created records use `VARCHAR(191)` IDs containing LUUID values.
- Coordinate server-facing behavior through the JSON API and WebSocket
  contracts, not shared runtime code.
