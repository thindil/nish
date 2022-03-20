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
import aliases, commands, constants, help, history, input, options, output,
  variables

func showCommandLineHelp() {.gcsafe, locks: 0, raises: [], tags: [].} =
  ## Show the program arguments help
  debugEcho """Available arguments are:
    -c [command]  - Run the selected command in shell and quit
    -db [path]    - Set the shell database to the selected file
    -h, --help    - Show this help and quit
    -v, --version - Show the shell version info"""
  quit QuitSuccess

func showProgramVersion() {.gcsafe, locks: 0, raises: [], tags: [].} =
  ## Show the program version
  debugEcho """
    Nish version: """ & shellVersion & """

    Copyright: 2021-2022 Bartek Jasicki <thindil@laeran.pl>
    License: 3-Clause BSD"""
  quit QuitSuccess

proc quitShell(returnCode: int; db: DbConn) {.gcsafe, sideEffect,
    raises: [], tags: [DbEffect, WriteIOEffect, ReadEnvEffect, TimeEffect].} =
  ## Close the shell database and quit from the program with the selected return code
  try:
    db.close()
  except DbError as e:
    quit showError("Can't close properly the shell database. Reason:" & e.msg)
  quit returnCode

proc startDb(dbpath: string): DbConn {.gcsafe, sideEffect, raises: [],
    tags: [ReadIOEffect, WriteDirEffect, DbEffect, WriteIOEffect, ReadEnvEffect,
        TimeEffect].} =
  ## Open connection to the shell database. Create database if not exists.
  ## Set the historyIndex to the last command
  try:
    discard existsOrCreateDir(parentDir(dbpath))
  except OSError, IOError:
    discard showError("Can't create directory for the shell's database. Reason: " &
        getCurrentExceptionMsg())
    return nil
  try:
    result = open(dbpath, "", "", "")
  except DbError as e:
    discard showError("Can't open the shell's database. Reason: " & e.msg)
    return nil
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
  try:
    result.exec(sql(sqlQuery))
  except DbError as e:
    discard showError("Can't create 'aliases' table. Reason: " & e.msg)
    return nil
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
  try:
    result.exec(sql(sqlQuery))
  except DbError as e:
    discard showError("Can't create 'options' table. Reason: " & e.msg)
    return nil
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
  try:
    result.exec(sql(sqlQuery))
  except DbError as e:
    discard showError("Can't create 'variables' table. Reason: " & e.msg)
    return nil

proc main() {.gcsafe, sideEffect, raises: [ValueError], tags: [ReadIOEffect,
    WriteIOEffect, ExecIOEffect, RootEffect].} =
  ## The main procedure of the shell

  var
    userInput: OptParser
    commandName, inputString: string = ""
    options: OptParser = initOptParser(shortNoVal = {'h', 'v'}, longNoVal = @[
        "help", "version"])
    historyIndex: int
    oneTimeCommand, conjCommands: bool = false
    returnCode: int = QuitSuccess
    aliases = initOrderedTable[string, int]()
    dbpath: string = getConfigDir() & DirSep & "nish" & DirSep & "nish.db"
    helpContent = initTable[string, HelpEntry]()

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
        inputString = key
      else:
        # Set the path to the shell database
        dbpath = key
      break
    else: discard

  # Connect to the shell database
  let db: DbConn = startDb(dbpath)

  # Stop shell if connection to its database was unsuccesful
  if db == nil:
    quit QuitFailure

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
      # Run only one command, don't show prompt and wait for the user input,
      # if there is still some data in last entered user input, also don't
      # ask for more.
      if not oneTimeCommand and inputString.len() == 0:
        # Write prompt
        showPrompt(not oneTimeCommand, commandName, returnCode)
        # Get the user input and parse it
        var inputChar: char = '\0'
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
                let currentHistoryLength: int = historyLength(db)
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
      let arguments: string = getArguments(userInput, conjCommands)
      inputString = join(userInput.remainingArgs(), " ");
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
        elif arguments == "add":
          returnCode = addVariable(historyIndex, db)
        # Edit an existing variable
        elif arguments.startsWith("edit"):
          returnCode = editVariable(arguments, historyIndex, db)
        else:
          returnCode = showUnknownHelp(arguments, "variable", "variables")
          historyIndex = updateHistory("variable " & arguments, db, returnCode)
      # Various commands related to the shell's commands' history
      of "history":
        # No subcommand entered, show available options
        if arguments.len() == 0:
          historyIndex = helpHistory(db)
        # Clear the shell's commands' history
        elif arguments == "clear":
          historyIndex = clearHistory(db)
        # Show the last executed shell's commands
        elif arguments == "show":
          historyIndex = showHistory(db)
        else:
          returnCode = showUnknownHelp(arguments, "history", "history")
          historyIndex = updateHistory("history " & arguments, db, returnCode)
      # Various commands related to the shell's options
      of "options":
        # No subcommand entered, show available options
        if arguments.len() == 0:
          helpOptions(db)
          historyIndex = updateHistory("options", db)
        # Show the list of available options
        elif arguments == "show":
          showOptions(db)
          historyIndex = updateHistory("options show", db)
        elif arguments.startsWith("set"):
          returnCode = setOptions(arguments, db)
          historyIndex = updateHistory("options set", db, returnCode)
          updateHelp(helpContent, db)
        elif arguments.startsWith("reset"):
          returnCode = resetOptions(arguments, db)
          historyIndex = updateHistory("options reset", db, returnCode)
          updateHelp(helpContent, db)
        else:
          returnCode = showUnknownHelp(arguments, "options", "options")
          historyIndex = updateHistory("options " & arguments, db, returnCode)
      # Various commands related to the aliases (like show list of available
      # aliases, add, delete, edit them)
      of "alias":
        # No subcommand entered, show available options
        if arguments.len() == 0:
          historyIndex = helpAliases(db)
        # Show the list of available aliases
        elif arguments.startsWith("list"):
          listAliases(arguments, historyIndex, aliases, db)
        # Delete the selected alias
        elif arguments.startsWith("delete"):
          returnCode = deleteAlias(arguments, historyIndex, aliases, db)
        # Show the selected alias
        elif arguments.startsWith("show"):
          returnCode = showAlias(arguments, historyIndex, aliases, db)
        # Add a new alias
        elif arguments.startsWith("add"):
          returnCode = addAlias(historyIndex, aliases, db)
        # Add a new alias
        elif arguments.startsWith("edit"):
          returnCode = editAlias(arguments, historyIndex, aliases, db)
        else:
          returnCode = showUnknownHelp(arguments, "alias", "aliases")
          historyIndex = updateHistory("alias " & arguments, db, returnCode)
      # Execute external command or alias
      else:
        let commandToExecute: string = commandName & " " & arguments
        # Check if command is an alias, if yes, execute it
        if commandName in aliases:
          returnCode = execAlias(arguments, commandName, aliases, db)
          historyIndex = updateHistory(commandToExecute, db, returnCode)
          continue
        # Execute external command
        returnCode = execCmd(commandToExecute)
        historyIndex = updateHistory(commandToExecute, db, returnCode)
    except:
      returnCode = showError()
    finally:
      # If there is more commands to execute check if the next commands should
      # be executed. if the last command wasn't success and commands conjuncted
      # with && or the last command was success and command disjuncted, reset
      # the input, don't execute more commands.
      if inputString.len() > 0 and ((returnCode != QuitSuccess and
          conjCommands) or (returnCode == QuitSuccess and not conjCommands)):
        inputString = ""
      # Run only one command, quit from the shell
      if oneTimeCommand and inputString.len() == 0:
        quitShell(returnCode, db)

main()
