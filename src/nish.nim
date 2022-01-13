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
  if not promptEnabled:
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

proc showError(message: string = ""): int {.gcsafe, locks: 0, sideEffect,
    raises: [IOError, ValueError], tags: [WriteIOEffect].} =
  ## Print the message to standard error and set the shell return
  ## code to error. If message is empty, print the current exception message
  if message == "":
    stderr.styledWriteLine(fgRed, getCurrentExceptionMsg())
  else:
    stderr.styledWriteLine(fgRed, message)
  result = QuitFailure

func updateHistory(commandToAdd: string; db: DbConn): int {.gcsafe, raises: [
    ValueError, DbError], tags: [ReadDbEffect, WriteDbEffect].} =
  ## Add the selected command to the shell history and increase the current
  ## history index
  result = parseInt(db.getValue(sql"SELECT COUNT(command) FROM history"))
  if result == maxHistoryLength:
    db.exec(sql"DELETE FROM history ORDER BY command ASC LIMIT(1)");
    result.dec()
  db.exec(sql"INSERT INTO history (command) VALUES (?)", commandToAdd)
  result.inc()

func quitShell(returnCode: int; db: DbConn) {.gcsafe, locks: 0, raises: [
    DbError], tags: [DbEffect].} =
  ## Close the shell database and quit from the program with the selected return code
  db.close()
  quit returnCode

proc startDb(dbpath: string): DbConn {.gcsafe, raises: [OSError, IOError],
    tags: [ReadIOEffect, WriteDirEffect, DbEffect].} =
  ## Open connection to the shell database. Create database if not exists
  discard existsOrCreateDir(parentDir(dbpath))
  result = open(dbpath, "", "", "")
  # Create a new database if not exists
  result.exec(sql"""CREATE TABLE IF NOT EXISTS aliases (
               id          INTEGER       PRIMARY KEY,
               name        VARCHAR(50)   NOT NULL,
               path        TEXT          NOT NULL,
               recursive   BOOLEAN       NOT NULL,
               commands    VARCHAR(4096) NOT NULL,
               description VARCHAR(4096) NOT NULL
            )""")
  result.exec(sql"""CREATE TABLE IF NOT EXISTS "history" (
               "command"	VARCHAR(4096) NOT NULL
            )""")

func setAliases(aliases: var OrderedTable[string, int]; directory: string;
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

  dbQuery.add(" ORDER BY id ASC")
  for dbResult in db.fastRows(sql(dbQuery)):
    aliases[dbResult[1]] = parseInt(dbResult[0])

proc changeDirectory(newDirectory: string; aliases: var OrderedTable[string,
    int]; db: DbConn): int {.gcsafe, raises: [DbError, ValueError, IOError,
        OSError], tags: [ReadEnvEffect, ReadIOEffect, ReadDbEffect,
        WriteIOEffect].} =
  ## Change the current directory for the shell
  let path: string = expandFilename(absolutePath(expandTilde(newDirectory)))
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
    aliases = initOrderedTable[string, int]()
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
        showPrompt(not oneTimeCommand, commandName, returnCode)
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
                showOutput(history[historyIndex], false, not oneTimeCommand,
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
                showOutput(history[historyIndex], false, not oneTimeCommand,
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
          showOutput("""Available commands are: cd, exit, help, set, unset, alias, alias list, alias
  delete, alias show

        To see more information about the command, type help [command], for
        example: help cd.
        """, true, not oneTimeCommand, commandName, returnCode)
          historyIndex = updateHistory("help", db)
        elif userInput.key == "cd":
          showOutput("""Usage: cd [directory]

        You must have permissions to enter the directory and directory
        need to exists.
        """, true, not oneTimeCommand, commandName, returnCode)
          historyIndex = updateHistory("help cd", db)
        elif userInput.key == "exit":
          showOutput("""Usage: exit

        Exit from the shell.
        """, true, not oneTimeCommand, commandName, returnCode)
          historyIndex = updateHistory("help exit", db)
        elif userInput.key == "help":
          showOutput("""Usage help ?command?

        If entered only as help, show the list of available commands,
        when also command entered, show the information about the selected
        command.
        """, true, not oneTimeCommand, commandName, returnCode)
          historyIndex = updateHistory("help help", db)
        elif userInput.key == "set":
          showOutput("""Usage set [name=value]

        Set the environment variable with the selected name and value.
          """, true, oneTimeCommand, commandName, returnCode)
          historyIndex = updateHistory("help set", db)
        elif userInput.key == "unset":
          showOutput("""Usage unset [name]

        Remove the environment variable with the selected name.
          """, true, not oneTimeCommand, commandName, returnCode)
          historyIndex = updateHistory("help unset", db)
        elif userInput.key == "alias":
          userInput.next()
          # If user entered only "alias", show the help for it
          if userInput.kind == cmdEnd:
            showOutput("""Usage: alias ?subcommand?

        If entered without subcommand, show the list of available subcommands
        for aliases. Otherwise, execute the selected subcommand.
        """, true, not oneTimeCommand, commandName, returnCode)
            historyIndex = updateHistory("help alias", db)
          elif userInput.key == "list":
            showOutput("""Usage: alias list ?all?

        Show the list of all available aliases in the current directory. If parameter
        all added, show all declared aliases.
        """, true, not oneTimeCommand, commandName, returnCode)
            historyIndex = updateHistory("help alias list", db)
          elif userInput.key == "delete":
            showOutput("""Usage: alias delete [index]

        Delete the alias with the selected index.
        """, true, not oneTimeCommand, commandName, returnCode)
            historyIndex = updateHistory("help alias delete", db)
          elif userInput.key == "show":
            showOutput("""Usage: alias show [index]

        Show details (description, commands, etc) for the alias with the selected index.
        """, true, not oneTimeCommand, commandName, returnCode)
            historyIndex = updateHistory("help alias show", db)
          else:
            returnCode = showError("Unknown subcommand `" & userInput.key &
              "` for `alias`. To see all available aliases commands, type `alias`.")
        else:
          returnCode = showError("Uknown command '" & userInput.key & "'")
      # Change current directory
      of "cd":
        userInput.next()
        if userInput.kind != cmdEnd:
          returnCode = changeDirectory(userInput.key, aliases, db)
          if returnCode == QuitSuccess:
            historyIndex = updateHistory("cd " & userInput.key, db)
      # Set the environment variable
      of "set":
        userInput.next()
        if userInput.kind != cmdEnd:
          let varValues = userInput.key.split("=")
          if varValues.len() > 1:
            try:
              putEnv(varValues[0], varValues[1])
              showOutput("Environment variable '" & varValues[0] &
                  "' set to '" & varValues[1] & "'", true, not oneTimeCommand,
                      commandName, returnCode)
              historyIndex = updateHistory("set " & userInput.key, db)
            except OSError:
              returnCode = showError()
      # Delete environment variable
      of "unset":
        userInput.next()
        if userInput.kind != cmdEnd:
          try:
            delEnv(userInput.key)
            showOutput("Environment variable '" & userInput.key & "' removed",
                true, not oneTimeCommand, commandName, returnCode)
            historyIndex = updateHistory("unset " & userInput.key, db)
          except OSError:
            returnCode = showError()
      # Various commands related to the aliases (like show list of available
      # aliases, add, delete, edit them)
      of "alias":
        userInput.next()
        # No subcommand entered, show available options
        if userInput.kind == cmdEnd:
          showOutput("""Available subcommands are: list, delete, show

        To see more information about the subcommand, type help alias [command],
        for example: help alias list.
        """, true, not oneTimeCommand, commandName, returnCode)
          historyIndex = updateHistory("alias", db)
        # Show the list of available aliases
        elif userInput.key == "list":
          showOutput("Available aliases are:", true, false, "", QuitSuccess)
          showOutput("ID Name Description", true, false, "",
            QuitSuccess)
          userInput.next()
          if userInput.kind == cmdEnd:
            historyIndex = updateHistory("alias list", db)
            for alias in aliases.values:
              let row = db.getRow(sql"SELECT id, name, description FROM aliases WHERE id=?",
                alias)
              showOutput(row[0] & " " & row[1] & " " & row[2], true, false, "",
                QuitSuccess)
          elif userInput.key == "all":
            historyIndex = updateHistory("alias list all", db)
            for row in db.fastRows(sql"SELECT id, name, description FROM aliases"):
              showOutput(row[0] & " " & row[1] & " " & row[2], true, false, "",
                QuitSuccess)
        # Delete the selected alias
        elif userInput.key == "delete":
          userInput.next()
          if userInput.kind == cmdEnd:
            returnCode = showError("Enter the Id of the alias to delete.")
          else:
            if db.execAffectedRows(sql"DELETE FROM aliases WHERE id=?",
                userInput.key) == 0:
              returnCode = showError("The alias with the Id: " & userInput.key &
                " doesn't exists.")
            else:
              historyIndex = updateHistory("alias delete", db)
              aliases.setAliases(getCurrentDir(), db)
              showOutput("Deleted the alias with Id: " & userInput.key, true,
                  false, "", QuitSuccess)
        # Show the selected alias
        elif userInput.key == "show":
          userInput.next()
          if userInput.kind == cmdEnd:
            returnCode = showError("Enter the Id of the alias to show.")
          else:
            let row = db.getRow(sql"SELECT name, commands, description FROM aliases WHERE id=?",
                userInput.key)
            if row[0] == "":
              returnCode = showError("The alias with the Id: " & userInput.key &
                " doesn't exists.")
            else:
              historyIndex = updateHistory("alias show", db)
              showOutput("Id: " & userInput.key, true, false, "", QuitSuccess)
              showOutput("Name: " & row[0], true, false, "", QuitSuccess)
              showOutput("Description: " & row[2], true, false, "", QuitSuccess)
              showOutput("Commands: ", true, false, "", QuitSuccess)
              showOutput(row[1], true, false, "", QuitSuccess)
        else:
          returnCode = showError("Unknown subcommand `" & userInput.key &
            "` for `alias`. To see all available aliases commands, type `alias`.")
      # Execute external command or alias
      else:
        let commandToExecute = commandName & " " &
          join(userInput.remainingArgs(), " ")
        # Check if command is an alias, if yes, execute it
        if commandName in aliases:
          let
            currentDirectory = getCurrentDir()
            commandArguments: seq[string] = userInput.remainingArgs()
          for command in splitLines(db.getValue(
              sql"SELECT commands FROM aliases WHERE id=?",
              aliases[commandName])):
            # Convert all $number in command to arguments taken from the user
            # input
            var
              argumentPosition: int = command.find('$')
              newCommand: string = command
            while argumentPosition > -1:
              var argumentNumber: int = parseInt(command[argumentPosition + 1] & "")
              # Not enough argument entered by the user, quit with error
              if argumentNumber > commandArguments.len():
                returnCode = showError("Not enough arguments entered")
                break
              newCommand = command.replace(command[
                  argumentPosition..argumentPosition + 1], commandArguments[
                      argumentNumber - 1])
              argumentPosition = newCommand.find('$')
            if returnCode == QuitFailure:
              break;
            # Threat cd command specially, it should just change the current
            # directory for the alias
            if newCommand[0..2] == "cd ":
              returnCode = changeDirectory(newCommand[3..^1], aliases, db)
              if returnCode != QuitSuccess:
                break
              continue
            returnCode = execCmd(newCommand)
            if returnCode != QuitSuccess:
              break
          discard changeDirectory(currentDirectory, aliases, db)
          if returnCode == QuitSuccess:
            historyIndex = updateHistory(commandToExecute, db)
          continue
        # Execute external command
        returnCode = execCmd(commandToExecute)
        if returnCode == QuitSuccess:
          historyIndex = updateHistory(commandToExecute, db)
    except:
      returnCode = showError()
    finally:
      # Run only one command, quit from the shell
      if oneTimeCommand:
        quitShell(returnCode, db)

main()
