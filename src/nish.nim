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
import aliases, commands, constants, help, history, options, output, variables

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

func quitShell(returnCode: int; db: DbConn) {.gcsafe, locks: 0, raises: [
    DbError], tags: [DbEffect].} =
  ## Close the shell database and quit from the program with the selected return code
  db.close()
  quit returnCode

proc startDb(dbpath: string): DbConn {.gcsafe, sideEffect, raises: [OSError,
    IOError], tags: [ReadIOEffect, WriteDirEffect, DbEffect].} =
  ## Open connection to the shell database. Create database if not exists.
  ## Set the historyIndex to the last command
  discard existsOrCreateDir(parentDir(dbpath))
  result = open(dbpath, "", "", "")
  # Create a new database if not exists
  var sqlQuery = """CREATE TABLE IF NOT EXISTS aliases (
               id          INTEGER       PRIMARY KEY,
               name        VARCHAR(""" & $aliasNameLength &
      """) NOT NULL,
               path        VARCHAR(""" & $maxInputLength &
          """) NOT NULL,
               recursive   BOOLEAN       NOT NULL,
               commands    VARCHAR(""" & $maxInputLength &
      """) NOT NULL,
               description VARCHAR(""" & $maxInputLength & """) NOT NULL
            )"""
  result.exec(sql(sqlQuery))
  sqlQuery = """CREATE TABLE IF NOT EXISTS options (
                option VARCHAR(""" & $aliasNameLength &
          """) NOT NULL PRIMARY KEY,
                value	 VARCHAR(""" & $maxInputLength &
              """) NOT NULL,
                description VARCHAR(""" & $maxInputLength &
          """) NOT NULL,
                valuetype VARCHAR(""" & $maxInputLength &
          """) NOT NULL,
                defaultvalue VARCHAR(""" & $maxInputLength & """) NOT NULL
            )"""
  result.exec(sql(sqlQuery))
  sqlQuery = """CREATE TABLE IF NOT EXISTS variables (
               id          INTEGER       PRIMARY KEY,
               name        VARCHAR(""" & $aliasNameLength &
          """) NOT NULL,
               path        VARCHAR(""" & $maxInputLength &
          """) NOT NULL,
               recursive   BOOLEAN       NOT NULL,
               value       VARCHAR(""" & $maxInputLength &
          """) NOT NULL,
               description VARCHAR(""" & $maxInputLength & """) NOT NULL
            )"""
  result.exec(sql(sqlQuery))

proc main() {.gcsafe, sideEffect, raises: [IOError, ValueError, OSError],
    tags: [ReadIOEffect, WriteIOEffect, ExecIOEffect, RootEffect].} =
  ## The main procedure of the shell

  var
    userInput: OptParser
    commandName: string = ""
    options: OptParser = initOptParser(shortNoVal = {'h', 'v'}, longNoVal = @[
        "help", "version"])
    historyIndex: int
    oneTimeCommand: bool = false
    returnCode: int = QuitSuccess
    aliases = initOrderedTable[string, int]()
    dbpath: string = getHomeDir() & ".config/nish/nish.db"
    helpContent = initTable[string, string]()

  # Check the command line parameters entered by the user. Available options
  # are "-c [command]" to run only one command, "-h" or "--help" to show
  # help about the shell's command line arguments, "-v" or "--version" to show
  # the shell's version info and "-db [path]" to set path to the shell's
  # database
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

  # Initialize the shell's commands history
  historyIndex = initHistory(db, helpContent)

  # Initialize the shell's options system
  initOptions(helpContent)

  # Initialize the shell's aliases system
  aliases = initAliases(helpContent, db)

  # Initialize the shell's build-in commands
  initCommands(helpContent)

  # Initialize the shell's environment variables system
  initVariables(helpContent, db)

  # Set the shell's help
  updateHelp(helpContent, db)
  setMainHelp(helpContent)

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
              if inputChar == 'A' and historyIndex > 0:
                inputString = getHistory(historyIndex, db)
                stdout.eraseLine()
                showOutput(inputString, false, not oneTimeCommand,
                    commandName, returnCode)
                historyIndex.dec()
                if historyIndex < 1:
                  historyIndex = 1;
              # Arrow down key pressed
              elif inputChar == 'B' and historyIndex > 0:
                historyIndex.inc()
                let currentHistoryLength = historyLength(db)
                if historyIndex > currentHistoryLength:
                  historyIndex = currentHistoryLength
                inputString = getHistory(historyIndex, db)
                stdout.eraseLine()
                showOutput(inputString, false, not oneTimeCommand,
                    commandName, returnCode)
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
      # Set the command arguments
      var arguments: string = ""
      userInput.next()
      while userInput.kind != cmdEnd:
        if userInput.key == "&&":
          userInput.next()
          break
        case userInput.kind
        of cmdLongOption:
          arguments.add("--" & userInput.key & "=" & userInput.val)
        of cmdShortOption:
          arguments.add("-" & userInput.key)
        of cmdArgument:
          arguments.add(userInput.key)
        of cmdEnd:
          discard
        arguments.add(" ")
        userInput.next()
      arguments = strip(arguments)
      # Parse commands
      case commandName
      # Quit from shell
      of "exit":
        historyIndex = updateHistory("exit", db)
        quitShell(returnCode, db)
      # Show help screen
      of "help":
        returnCode = showHelp(arguments, helpContent, db)
      # Change current directory
      of "cd":
        returnCode = cdCommand(arguments, aliases, db)
        historyIndex = historyLength(db)
      # Set the environment variable
      of "set":
        returnCode = setCommand(arguments, db)
        historyIndex = historyLength(db)
      # Delete environment variable
      of "unset":
        returnCode = unsetCommand(arguments, db)
        historyIndex = historyLength(db)
      # Various commands related to environment variables
      of "variable":
        # No subcommand entered, show available options
        if arguments.len() == 0:
          historyIndex = helpVariables(db)
        # Show the list of declared environment variables
        elif arguments.startsWith("list"):
          listVariables(arguments, historyIndex, db)
        # Delete the selected environment variable
        elif arguments.startsWith("delete"):
          returnCode = deleteVariable(arguments, historyIndex, db)
        # Add a new variable
        elif arguments.startsWith("add"):
          returnCode = addVariable(historyIndex, db)
        # Edit an existing variable
        elif arguments.startsWith("edit"):
          returnCode = editVariable(arguments, historyIndex, db)
        else:
          returnCode = showError("Unknown subcommand `" & arguments &
            "` for `variable`. To see all available variables commands, type `variable`.")
          historyIndex = updateHistory("variable " & arguments, db, returnCode)
      # Various commands related to the shell's commands' history
      of "history":
        userInput.next()
        # No subcommand entered, show available options
        if userInput.kind == cmdEnd:
          historyIndex = helpHistory(db)
        # Clear the shell's commands' history
        elif userInput.key == "clear":
          historyIndex = clearHistory(db)
        elif userInput.key == "show":
          historyIndex = showHistory(db)
        else:
          returnCode = showError("Unknown subcommand `" & userInput.key &
            "` for `history`. To see all available aliases commands, type `history`.")
      # Various commands related to the shell's options
      of "options":
        userInput.next()
        # No subcommand entered, show available options
        if userInput.kind == cmdEnd:
          helpOptions(db)
          historyIndex = updateHistory("options", db)
        # Show the list of available options
        elif userInput.key == "show":
          showOptions(db)
          historyIndex = updateHistory("options show", db)
        elif userInput.key == "set":
          returnCode = setOptions(userInput, db)
          historyIndex = updateHistory("options set", db, returnCode)
          updateHelp(helpContent, db)
        elif userInput.key == "reset":
          returnCode = resetOptions(userInput, db)
          historyIndex = updateHistory("options reset", db, returnCode)
          updateHelp(helpContent, db)
        else:
          returnCode = showError("Unknown subcommand `" & userInput.key &
            "` for `options`. To see all available aliases commands, type `options`.")
          historyIndex = updateHistory("options " & userInput.key, db, returnCode)
      # Various commands related to the aliases (like show list of available
      # aliases, add, delete, edit them)
      of "alias":
        userInput.next()
        # No subcommand entered, show available options
        if userInput.kind == cmdEnd:
          historyIndex = helpAliases(db)
        # Show the list of available aliases
        elif userInput.key == "list":
          listAliases(userInput, historyIndex, aliases, db)
        # Delete the selected alias
        elif userInput.key == "delete":
          returnCode = deleteAlias(userInput, historyIndex, aliases, db)
        # Show the selected alias
        elif userInput.key == "show":
          returnCode = showAlias(userInput, historyIndex, aliases, db)
        # Add a new alias
        elif userInput.key == "add":
          returnCode = addAlias(historyIndex, aliases, db)
        # Add a new alias
        elif userInput.key == "edit":
          returnCode = editAlias(userInput, historyIndex, aliases, db)
        else:
          returnCode = showError("Unknown subcommand `" & userInput.key &
            "` for `alias`. To see all available aliases commands, type `alias`.")
          historyIndex = updateHistory("alias " & userInput.key, db, returnCode)
      # Execute external command or alias
      else:
        let
          arguments = if userInput.remainingArgs().len() > 0: " " & join(
            userInput.remainingArgs(), " ") else: ""
          commandToExecute = commandName & arguments
        # Check if command is an alias, if yes, execute it
        if commandName in aliases:
          returnCode = execAlias(userInput, commandName, aliases, db)
          historyIndex = updateHistory(commandToExecute, db, returnCode)
          continue
        # Execute external command
        returnCode = execCmd(commandToExecute)
        historyIndex = updateHistory(commandToExecute, db, returnCode)
    except:
      returnCode = showError()
    finally:
      # Run only one command, quit from the shell
      if oneTimeCommand:
        quitShell(returnCode, db)

main()
