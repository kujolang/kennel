# Command Boundaries

This document describes the command-family split used by the Kennel router.

## Router Responsibility

The entrypoint in kennel.kujo now performs only:

1. CLI parse
2. project-dir resolution
3. directory safety checks
4. command dispatch via dispatch_command

## Dependency Lifecycle Command Family

- init
- add
- install
- update
- remove
- list
- info
- search
- validate
- install-hosted

## Hosted Registry Command Family

- login
- publish
- yank
- access
- visibility
- api-search
- api-metadata

## Notes

- The dispatch split keeps command routing concerns isolated from parse/path validation in main.
- Hosted and dependency command families are intentionally grouped for future module extraction without changing CLI behavior.
