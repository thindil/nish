# Changelog
All notable changes to this project will be documented in this file.

## [Unreleased]

### Added
- Shell's commands' history now remember directory in which the command used
  last time and prioritize the local commands
- Support for shell's read-only options

### Changed
- Better getting commands from the shell's history

### Fixed
- Reading command line parameters, when there is set database path and the
  command to execute
- The program's help about setting the database's path
- Showing error information during Tab completion
- Showing error information during getting command from the shell's history
- Showing error message on standard output instead of standard error

## [0.2.0] - 2022-05-09

### Added
- Checks for valid name and path during creating or editing the shell's aliases
- Checks for valid name and path during creating or editing the shell's
  environment variables
- When there is partial input, looking in the shell's history returns the first
  command which starts with the input
- Ability to insert characters into the current input of the user
- Ability to move between start and end of the current input of the user with
  Home and End keys
- Simple Tab completion for command with names of files and directories
- Coloring the user entered command on green when valid and red on invalid
- Ability to use environment variables inside the shell's environment variables

### Changed
- Updated README.md
- Updated adding a new alias form
- Updated editing an existing alias form
- Updated look of list of available aliases, help entries, showing last
  commands from shell's history, list of shell's options, list of environment
  variables, showing the selected alias details, list of shell's options
- Updated adding a new variable form
- Updated editing an existing variable form

### Fixed
- Merging commands with || in aliases doesn't work properly
- Information about unknown help topic
- Parsing aliases arguments when the user input contains $ sign
- Handling aliases arguments with whitespaces

## [0.1.0] - 2022-02-23
- Initial release
