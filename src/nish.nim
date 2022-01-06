# Copyright © 2021-2022 Bartek Jasicki <thindil@laeran.pl>
# All rights reserved.
#
# Redistribution and use in source and binary forms, with or without
# modification, are permitted provided that the following conditions are met:
# 1. Redistributions of source code must retain the above copyright
# notice, this list of conditions and the following disclaimer.
# 2. Redistributions in binary form must reproduce the above copyright
# notice, this list of conditions and the following disclaimer in the
# documentation and/or other materials provided with the distribution.
# 3. Neither the name of the copyright holder nor the
# names of its contributors may be used to endorse or promote products
# derived from this software without specific prior written permission.
#
# THIS SOFTWARE IS PROVIDED BY COPYRIGHT HOLDERS AND CONTRIBUTORS ''AS IS'' AND
# ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE IMPLIED
# WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE ARE
# DISCLAIMED. IN NO EVENT SHALL THE COPYRIGHT HOLDER OR CONTRIBUTORS BE LIABLE
# FOR ANY DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR CONSEQUENTIAL
# DAMAGES (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS OR
# SERVICES; LOSS OF USE, DATA, OR PROFITS; OR BUSINESS INTERRUPTION) HOWEVER
# CAUSED AND ON ANY THEORY OF LIABILITY, WHETHER IN CONTRACT, STRICT LIABILITY,
# OR TORT (INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY OUT OF THE USE
# OF THIS SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.

import std/[db_sqlite, os, osproc, parseopt, strutils, tables, terminal]

const
  maxInputLength = 4096
  maxHistoryLength = 500

proc showCommandLineHelp() {.gcsafe, locks: 0, sideEffect, raises: [],
                            tags: [].} =
  ## Show the program arguments help
  echo """Available arguments are:
    -c [command]  - Run the selected command in shell and quit
    -db [path]    - Set the shell database to the selected file
    -h, --help    - Show this help and quit
    -v, --version - Show the shell version info"""
  quit QuitSuccess

proc showProgramVersion() {.gcsafe, locks: 0, sideEffect, raises: [],
                            tags: [].} =
  ## Show the program version
  echo """
    Nish version 0.1.0
    Copyright: 2021-2022 Bartek Jasicki <thindil@laeran.pl>
    License: 3-Clause BSD"""
  quit QuitSuccess

proc showPrompt(promptEnabled: bool; previousCommand: string;
    resultCode: int) {.gcsafe, locks: 0, sideEffect, raises: [OSError, IOError,
        ValueError], tags: [ReadIOEffect, WriteIOEffect].} =
  ## Show the shell prompt if the shell wasn't started in one command mode
  if promptEnabled:
    return
  let
    currentDirectory: string = getCurrentDir()
    homeDirectory: string = getHomeDir()
  if endsWith(currentDirectory & "/", homeDirectory):
    stdout.styledWrite(fgBlue, "~")
  else:
    let homeIndex: int = currentDirectory.find(homeDirectory)
    if homeIndex > -1:
      stdout.styledWrite(fgBlue, "~/" & currentDirectory[homeIndex +
          homeDirectory.len()..^1])
    else:
      stdout.styledWrite(fgBlue, currentDirectory)
  if previousCommand != "" and resultCode != QuitSuccess:
    stdout.styledWrite(fgRed, "[" & $resultCode & "]")
  stdout.styledWrite(fgBlue, "# ")

proc showOutput(message: string; newLine: bool;
    promptEnabled: bool; previousCommand: string; returnCode: int) {.gcsafe,
        locks: 0, sideEffect, raises: [OSError, IOError, ValueError], tags: [
            ReadIOEffect, WriteIOEffect].} =
  ## Show the selected message and prompt (if enabled, default) to the user.
  ## If newLine is true, add a new line after message.
  showPrompt(promptEnabled, previousCommand, returnCode)
  if message != "":
    stdout.write(message)
    if newLine:
      stdout.writeLine("")
  stdout.flushFile()

proc showError(): int {.gcsafe, locks: 0, sideEffect, raises: [IOError,
    ValueError], tags: [WriteIOEffect].} =
  ## Print the exception message to standard error and set the shell return
  ## code to error
  stderr.styledWriteLine(fgRed, getCurrentExceptionMsg())
  result = QuitFailure

func updateHistory(commandToAdd: string; historyList: var seq[
    string]): int {.gcsafe, locks: 0, raises: [], tags: [].} =
  ## Add the selected command to the shell history and increase the current
  ## history index
  if historyList.len() == maxHistoryLength:
    historyList.delete(1)
  historyList.add(commandToAdd)
  result = historyList.len() - 1

func quitShell(returnCode: int; db: DbConn) {.gcsafe, locks: 0, raises: [
    DbError], tags: [DbEffect].} =
  ## Close the shell database and quit from the program with the selected return code
  db.close()
  quit returnCode

proc startDb(dbpath: string): DbConn {.gcsafe, raises: [OSError, IOError],
    tags: [ReadIOEffect, WriteDirEffect, DbEffect].} =
  ## Open connection to the shell database. Create database if not exists
  let dirExists: bool = existsOrCreateDir(parentDir(dbpath))
  result = open(dbpath, "", "", "")
  # Create a new database
  if not dirExists:
    result.exec(sql"""CREATE TABLE aliases (
                 id          INTEGER       PRIMARY KEY,
                 name        VARCHAR(50)   NOT NULL,
                 path        TEXT          NOT NULL,
                 recursive   BOOLEAN       NOT NULL,
                 commands    VARCHAR(4096) NOT NULL,
                 description VARCHAR(4096) NOT NULL,
              )""")

func setAliases(aliases: var Table[string, int]; directory: string;
    db: DbConn) {.gcsafe, raises: [ValueError, DbError], tags: [
    ReadDbEffect].} =
  ## Set the available aliases in the selected directory
  aliases.clear()
  var
    dbQuery: string = "SELECT id, name FROM aliases WHERE path='" & directory & "'"
    remainingDirectory: string = parentDir(directory)

  # Construct SQL querry, search for aliases also defined in parent directories
  # if they are recursive
  while remainingDirectory != "":
    dbQuery.add(" OR (path='" & remainingDirectory & "' AND recursive=1)")
    remainingDirectory = parentDir(remainingDirectory)

  for dbResult in db.fastRows(sql(dbQuery)):
    aliases[dbResult[1]] = parseInt(dbResult[0])

proc changeDirectory(newDirectory: string; aliases: var Table[string, int];
    db: DbConn): int {.gcsafe, raises: [DbError, ValueError, IOError,
        OSError], tags: [ReadEnvEffect, ReadIOEffect, ReadDbEffect,
        WriteIOEffect].} =
  ## Change the current directory for the shell
  let path: string = absolutePath(expandTilde(newDirectory))
  try:
    setCurrentDir(path)
    aliases.setAliases(path, db)
    result = QuitSuccess
  except OSError:
    result = showError()

proc main() {.gcsafe, sideEffect, raises: [IOError, ValueError, OSError],
    tags: [ReadIOEffect, WriteIOEffect, ExecIOEffect, RootEffect].} =
  ## The main procedure of the shell

  var
    userInput: OptParser
    commandName: string = ""
    options: OptParser = initOptParser(shortNoVal = {'h', 'v'}, longNoVal = @[
        "help", "version"])
    history: seq[string]
    historyIndex: int = 0
    oneTimeCommand: bool = false
    returnCode: int = QuitSuccess
    aliases = initTable[string, int]()
    dbpath: string = getHomeDir() & ".config/nish/nish.db"

  # Check the command line parameters entered by the user. Available options
  # are "-c [command]" to run only one command and "-h" or "--help" to show
  # help about the shell's command line arguments
  for kind, key, value in options.getopt():
    case kind
    of cmdShortOption:
      case key
      of "c":
        oneTimeCommand = true
      of "h":
        showCommandLineHelp()
      of "v":
        showProgramVersion()
    of cmdLongOption:
      case key
      of "help":
        showCommandLineHelp()
      of "version":
        showProgramVersion()
    of cmdArgument:
      if oneTimeCommand:
        # Set the command to execute in shell
        userInput = initOptParser(key)
      else:
        # Set the path to the shell database
        dbpath = key
      break
    else: discard

  # Connect to the shell database
  let db = startDb(dbpath)

  # Set available command aliases for the current directory
  aliases.setAliases(getCurrentDir(), db)

  # Start the shell
  while true:
    try:
      # Run only one command, don't show prompt and wait for the user input
      if not oneTimeCommand:
        # Write prompt
        showPrompt(oneTimeCommand, commandName, returnCode)
        # Get the user input and parse it
        var
          inputString = ""
          inputChar = '\0'
        # Read the user input until not meet new line character or the input
        # reach the maximum length
        while inputChar.ord() != 13 and inputString.len() < maxInputLength:
          # Backspace pressed, delete the last character from the user input
          if inputChar.ord() == 127:
            if inputString.len() > 0:
              inputString = inputString[0..^2]
              stdout.cursorBackward()
              stdout.write(" ")
              stdout.cursorBackward()
          # Escape or arrows keys pressed
          elif inputChar.ord() == 27:
            # Arrow key pressed
            if getch() == '[':
              # Arrow up key pressed
              inputChar = getch()
              if inputChar == 'A' and history.len() > 0:
                stdout.eraseLine()
                showOutput(history[historyIndex], false, oneTimeCommand,
                    commandName, returnCode)
                inputString = history[historyIndex]
                historyIndex.dec()
                if historyIndex < 0:
                  historyIndex = 0;
              # Arrow down key pressed
              elif inputChar == 'B' and history.len() > 0:
                historyIndex.inc()
                if historyIndex >= history.len():
                  historyIndex = history.len() - 1
                stdout.eraseLine()
                showOutput(history[historyIndex], false, oneTimeCommand,
                    commandName, returnCode)
                inputString = history[historyIndex]
          elif inputChar.ord() > 31:
            stdout.write(inputChar)
            inputString.add(inputChar)
          inputChar = getch()
        stdout.writeLine("")
        userInput = initOptParser(inputString)
        # Reset the return code of the program
        returnCode = QuitSuccess
      # Go to the first token
      userInput.next()
      # If it looks like an argument, it must be command name
      if userInput.kind == cmdArgument:
        commandName = userInput.key
      # No command name, back to beginning
      if commandName == "":
        continue
      # Parse commands
      case commandName
      # Quit from shell
      of "exit":
        quitShell(returnCode, db)
      # Show help screen
      of "help":
        userInput.next()
        # If user entered only "help", show the main help screen
        if userInput.kind == cmdEnd:
          showOutput("""Available commands are: cd, exit, help, set, unset

        To see more information about the command, type help [command], for
        example: help cd.
        """, true, oneTimeCommand, commandName, returnCode)
          historyIndex = updateHistory("help", history)
        elif userInput.key == "cd":
          showOutput("""Usage: cd [directory]

        You must have permissions to enter the directory and directory
        need to exists.
        """, true, oneTimeCommand, commandName, returnCode)
          historyIndex = updateHistory("help cd", history)
        elif userInput.key == "exit":
          showOutput("""Usage: exit

        Exit from the shell.
        """, true, oneTimeCommand, commandName, returnCode)
          historyIndex = updateHistory("help exit", history)
        elif userInput.key == "help":
          showOutput("""Usage help ?command?

        If entered only as help, show the list of available commands,
        when also command entered, show the information about the selected
        command.
        """, true, oneTimeCommand, commandName, returnCode)
          historyIndex = updateHistory("help help", history)
        elif userInput.key == "set":
          showOutput("""Usage set [name=value]

        Set the environment variable with the selected name and value.
          """, true, oneTimeCommand, commandName, returnCode)
          historyIndex = updateHistory("help set", history)
        elif userInput.key == "unset":
          showOutput("""Usage unset [name]

        Remove the environment variable with the selected name.
          """, true, oneTimeCommand, commandName, returnCode)
          historyIndex = updateHistory("help unset", history)
        else:
          showOutput("Uknown command '" & userInput.key & "'", true,
              oneTimeCommand, commandName, returnCode)
          returnCode = QuitFailure
      # Change current directory
      of "cd":
        userInput.next()
        if userInput.kind != cmdEnd:
          returnCode = changeDirectory(userInput.key, aliases, db)
          if returnCode == QuitSuccess:
            historyIndex = updateHistory("cd " & userInput.key, history)
      # Set the environment variable
      of "set":
        userInput.next()
        if userInput.kind != cmdEnd:
          let varValues = userInput.key.split("=")
          if varValues.len() > 1:
            try:
              putEnv(varValues[0], varValues[1])
              showOutput("Environment variable '" & varValues[0] &
                  "' set to '" & varValues[1] & "'", true, oneTimeCommand,
                      commandName, returnCode)
              historyIndex = updateHistory("set " & userInput.key, history)
            except OSError:
              returnCode = showError()
      # Delete environment variable
      of "unset":
        userInput.next()
        if userInput.kind != cmdEnd:
          try:
            delEnv(userInput.key)
            showOutput("Environment variable '" & userInput.key & "' removed",
                true, oneTimeCommand, commandName, returnCode)
            historyIndex = updateHistory("unset " & userInput.key, history)
          except OSError:
            returnCode = showError()
      # Execute external command or alias
      else:
        # Check if command is an alias, if yes, execute it
        if commandName in aliases:
          let currentDirectory = getCurrentDir()
          for command in splitLines(db.getValue(
              sql"SELECT commands FROM aliases WHERE id=?", aliases[commandName])):
            # Threat cd command specially, it should just change the current directory
            # for the alias
            if command[0..2] == "cd ":
              returnCode = changeDirectory(command[3..^1], aliases, db)
              if returnCode != QuitSuccess:
                break
              continue
            returnCode = execCmd(command)
            if returnCode != QuitSuccess:
              break
          discard changeDirectory(currentDirectory, aliases, db)
          if returnCode == QuitSuccess:
            historyIndex = updateHistory(commandName, history)
          continue
        # Execute external command
        let commandToExecute = commandName & " " &
          join(userInput.remainingArgs, " ")
        returnCode = execCmd(commandToExecute)
        if returnCode == QuitSuccess:
          historyIndex = updateHistory(commandToExecute, history)
    except:
      returnCode = showError()
    finally:
      # Run only one command, quit from the shell
      if oneTimeCommand:
        quitShell(returnCode, db)

main()
