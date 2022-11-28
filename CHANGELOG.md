# Changelog
All notable changes to this project will be documented in this file.

Tag **BREAKING** means the change break compatibility with a previous version
of the shell.

## [Unreleased]

### Added
- Directory separator to tab completion if the completion's result is a
  directory
- Tab completion now works also with commands not only with their arguments
- Support for Unicode in the user's input
- Ability to set the terminal's title. Can be enabled or disabled in the
  shell's options.
- Ability to enable or disable syntax highlighting for the user's input
- Ability to look for a command in the shell's commands' history
- Info about the amount of the last commands to `history list` command

## Changed
- **BREAKING**: Updated plugins' system. May require to add the installed
  plugins again, due how pre-command and post-command hooks are handled
  now
- Updated README.md
- Better syntax highlighting in the user's commands
- Better handling the user's input in various forms, like adding variables,
  aliases, etc.
- Better Tab completion: support for select a completion from the list
  of completions

### Fixed
- Clearing the plugin's table after failed adding the new plugin to the
  shell
- The shell option `promptCommand` should be writeable by the user
- Style issues in README.md
- Refreshing the user input when it is longer than a terminal width
- Don't mark environment variable as invalid command
- Better handling arguments in the test plugin
- Special keys not working with some terminal emulators
- Typos in CHANGELOG.md and README.md
- Getting stact trace for the shell's exception when build in debug mode
- Adding values of short options in entered commands
- Aliases don't return proper exit codes

## [0.4.0] - 2022-10-14

### Added
- **BREAKING**: Version to the plugins API
- Information about supported API version by plugin to `plugin show` command
- Information about used API calls by plugin to `plugin show` command
- Deleting a character with Backspace key in the middle of the user's input
- Canceling entering the command with Ctrl-c
- Showing error message when a plugin sends unknown request or response to the
  shell
- Ability to add, remove or replace the shell's commands with the shell's
  plugins
- Ability to add, remove or update the shell's help's entries with the shell's
  plugins

### Changed
- Updated README.md
- Updated contributing guide
- **BREAKING**: Better, more effective system of plugins
- Better help entry for list of subcommands for the selected command
- **BREAKING**: Better, more advanced system of help

### Fixed
- Typos in README.md
- Crash when trying to enter a directory outside the user's home directory tree
- Executing aliases which arguments contain whitespaces
- Backspace key during editing a command entered by the user

## [0.3.0] - 2022-07-29

### Added
- Shell's commands' history now remember directory in which the command used
  last time and prioritize the local commands
- Support for shell's read-only options
- Ability to select how the shell's history should be sorted
- Ability to reverse direction of the shell's history last commands list
- Ability to set the amount, order and direction of order of the last commands
  to show for `history list` command
- Ability to redirect output of aliases to standard error or the selected file
- Ability to set the output of program or script as the shell's prompt
- The shell's plugins' system

### Changed
- Better getting commands from the shell's history
- Better help entry for `history list` command
- Type of some the shell's options' to natural instead of integer
- Updated README.md
- **BREAKING**: Renamed command `history show` to `history list` to match other
  subcommands related to listings
- **BREAKING**: Renamed command `options show` to `options list` to match other
  subcommands related to listings

### Fixed
- Reading command line parameters, when there is set database path and the
  command to execute
- The program's help about setting the database's path
- Showing error information during Tab completion
- Showing error information during getting command from the shell's history
- Showing error message on standard output instead of standard error
- The look of `alias show` command when the description of the alias is empty
- Pressing Enter key repeat the last entered command
- The cursor position during editing a command

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
