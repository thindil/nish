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
import aliases, commands, completion, constants, directorypath, help, history,
    input, lstring, options, output, resultcode, variables

proc showCommandLineHelp*() {.gcsafe, sideEffect, locks: 0, raises: [], tags: [
    WriteIOEffect].} =
  ## FUNCTION
  ##
  ## Show the program arguments help
  ##
  ## RETURNS
  ##
  ## QuitSuccess when the program's arguments help was shown, otherwise
  ## QuitFailure.
  try:
    stdout.writeLine("""Available arguments are:
    -c [command]  - Run the selected command in shell and quit
    --db [path]   - Set the shell database to the selected file
    -h, --help    - Show this help and quit
    -v, --version - Show the shell version info""")
    stdout.flushFile()
  except IOError:
    quit QuitFailure
  quit QuitSuccess

proc showProgramVersion*() {.gcsafe, sideEffect, locks: 0, raises: [], tags: [
    WriteIOEffect].} =
  ## FUNCTION
  ##
  ## Show the program version
  ##
  ## RETURNS
  ##
  ## QuitSuccess when the program's arguments help was shown, otherwise
  ## QuitFailure.
  try:
    stdout.writeLine(x = """
    Nish version: 0.3.0

    Copyright: 2021-2022 Bartek Jasicki <thindil@laeran.pl>
    License: 3-Clause BSD""")
    stdout.flushFile()
  except IOError:
    quit QuitFailure
  quit QuitSuccess

proc quitShell*(returnCode: ResultCode; db: DbConn) {.gcsafe, sideEffect,
    raises: [], tags: [DbEffect, WriteIOEffect, ReadEnvEffect, TimeEffect].} =
  ## FUNCTION
  ##
  ## Close the shell database and quit from the program with the selected return code
  ##
  ## PARAMETERS
  ##
  ## * returnCode - the exit code to return with the end of the program
  ## * db         - the connection to the shell's database
  try:
    db.close()
  except DbError:
    quit showError(message = "Can't close properly the shell database. Reason:",
        e = getCurrentException()).int
  quit int(returnCode)

proc startDb*(dbPath: DirectoryPath): DbConn {.gcsafe, sideEffect, raises: [],
    tags: [ReadIOEffect, WriteDirEffect, DbEffect, WriteIOEffect, ReadEnvEffect,
        TimeEffect].} =
  ## FUNCTION
  ##
  ## Open connection to the shell database. Create database if not exists.
  ## Set the historyIndex to the last command
  ##
  ## PARAMETERS
  ##
  ## * dbPath - The full path to the database file
  ##
  ## RETURNS
  ##
  ## Pointer to the database connection. If connection cannot be established,
  ## returns nil.
  try:
    discard existsOrCreateDir(dir = parentDir(path = $dbPath))
  except OSError, IOError:
    discard showError(message = "Can't create directory for the shell's database. Reason: ",
        e = getCurrentException())
    return nil
  let dbExists: bool = fileExists($dbPath)
  try:
    result = open(connection = $dbPath, user = "", password = "", database = "")
  except DbError:
    discard showError(message = "Can't open the shell's database. Reason: ",
        e = getCurrentException())
    return nil
  let
    optionName: OptionName = try:
        initLimitedString(capacity = 9, text = "dbVersion")
      except CapacityError:
        discard showError(message = "Can't set optionName. Reason: ",
            e = getCurrentException())
        return nil
    optionValue: OptionValue = try:
        initLimitedString(capacity = 1, text = "2")
      except CapacityError:
        discard showError(message = "Can't set optionValue. Reason: ",
            e = getCurrentException())
        return nil
  # Create a new database if not exists
  if not dbExists:
    var sqlQuery: string = """CREATE TABLE aliases (
                 id          INTEGER       PRIMARY KEY,
                 name        VARCHAR(""" & $aliasNameLength &
            """) NOT NULL,
                 path        VARCHAR(""" & $maxInputLength &
            """) NOT NULL,
                 recursive   BOOLEAN       NOT NULL,
                 commands    VARCHAR(""" & $maxInputLength &
            """) NOT NULL,
                 description VARCHAR(""" & $maxInputLength &
            """) NOT NULL,
                 output VARCHAR(""" & $maxInputLength &
            """) NOT NULL DEFAULT 'stdout')"""
    try:
      result.exec(query = sql(query = sqlQuery))
    except DbError:
      discard showError(message = "Can't create 'aliases' table. Reason: ",
          e = getCurrentException())
      return nil
    if createOptionsDb(db = result) == QuitFailure:
      return nil;
    try:
      setOption(optionName = optionName, value = optionValue,
          description = initLimitedString(capacity = 42,
          text = "Version of the database schema (read only)"),
          valueType = ValueType.natural, db = result, readOnly = 1)
    except CapacityError:
      discard showError(message = "Can't set database schema. Reason: ",
          e = getCurrentException())
      return nil
  # If database version is different than the newest, update database
  try:
    if parseInt(s = $getOption(optionName = optionName, db = result,
        defaultValue = initLimitedString(capacity = 1, text = "0"))) < parseInt(
            s = $optionValue):
      if updateOptionsDb(db = result) == QuitFailure:
        return nil
      if updateHistoryDb(db = result) == QuitFailure:
        return nil
      if updateAliasesDb(db = result) == QuitFailure:
        return nil
      setOption(optionName = optionName, value = optionValue,
          description = initLimitedString(capacity = 42,
          text = "Version of the database schema (read only)"),
          valueType = ValueType.natural, db = result)
  except CapacityError, DbError, ValueError:
    discard showError(message = "Can't update database. Reason: ",
        e = getCurrentException())
    return nil

proc main() {.gcsafe, sideEffect, raises: [], tags: [ReadIOEffect,
    WriteIOEffect, ExecIOEffect, RootEffect].} =
  ## FUNCTION
  ##
  ## The main procedure of the shell

  var
    userInput: OptParser
    commandName: string = ""
    inputString: UserInput = emptyLimitedString(capacity = maxInputLength)
    options: OptParser = initOptParser(shortNoVal = {'h', 'v'}, longNoVal = @[
        "help", "version"])
    historyIndex: HistoryRange
    oneTimeCommand, conjCommands, keyWasArrow, insertMode: bool = false
    returnCode: ResultCode = QuitSuccess.ResultCode
    aliases: AliasesList = initOrderedTable[AliasName, int]()
    dbPath: DirectoryPath = DirectoryPath(getConfigDir() & DirSep & "nish" &
        DirSep & "nish.db")
    helpContent = initTable[string, HelpEntry]()
    cursorPosition: Natural = 0

  # Check the command line parameters entered by the user. Available options
  # are "-c [command]" to run only one command, "-h" or "--help" to show
  # help about the shell's command line arguments, "-v" or "--version" to show
  # the shell's version info and "-db [path]" to set path to the shell's
  # database
  while true:
    options.next()
    case options.kind
    of cmdEnd:
      break
    of cmdShortOption, cmdLongOption:
      case options.key
      of "c":
        oneTimeCommand = true
        options.next()
        try:
          inputString.setString(text = options.key)
        except CapacityError:
          quit showError(message = "The entered command is too long.").int
      of "h", "help":
        showCommandLineHelp()
      of "v", "version":
        showProgramVersion()
      of "db":
        dbPath = DirectoryPath(options.val)
    else: discard

  # Connect to the shell database
  let db: DbConn = startDb(dbPath = dbPath)

  # Stop shell if connection to its database was unsuccesful
  if db == nil:
    quit QuitFailure

  # Initialize the shell's commands history
  historyIndex = initHistory(db = db, helpContent = helpContent)

  # Initialize the shell's options system
  initOptions(helpContent = helpContent)

  # Initialize the shell's aliases system
  aliases = initAliases(helpContent = helpContent, db = db)

  # Initialize the shell's build-in commands
  initCommands(helpContent = helpContent)

  # Initialize the shell's environment variables system
  initVariables(helpContent = helpContent, db = db)

  # Set the shell's help
  updateHelp(helpContent = helpContent, db = db)
  setMainHelp(helpContent = helpContent)

  proc refreshInput() {.gcsafe, sideEffect, raises: [], tags: [WriteIOEffect,
      ReadIOEffect].} =
    ## FUNCTION
    ##
    ## Refresh the user input, clear the old and show the new. Color the entered
    ## command on green if it is valid or red if invalid
    try:
      stdout.eraseLine()
      let
        input: UserInput = try:
            initLimitedString(capacity = maxInputLength, text = strip(
                s = $inputString, trailing = false))
          except CapacityError:
            emptyLimitedString(capacity = maxInputLength)
        spaceIndex: ExtendedNatural = input.find(sub = ' ')
        command: UserInput = try:
            initLimitedString(capacity = maxInputLength, text = (if spaceIndex <
                1: $input else: $input[0..spaceIndex - 1]))
          except CapacityError:
            emptyLimitedString(capacity = maxInputLength)
        commandArguments: UserInput = try:
            initLimitedString(capacity = maxInputLength, text = (if spaceIndex <
                1: "" else: $input[spaceIndex..^1]))
          except CapacityError:
            emptyLimitedString(capacity = maxInputLength)
      var color: ForegroundColor = try:
          if findExe(exe = $command).len() > 0:
            fgGreen
          else:
            fgRed
        except OSError:
          fgGreen
      if color == fgRed:
        if $command in ["exit", "cd", "help", "history", "variable", "options",
            "set", "unset"]:
          color = fgGreen
        elif aliases.contains(key = command):
          color = fgGreen
      showOutput(message = $command, newLine = false,
          promptEnabled = not oneTimeCommand,
          previousCommand = commandName, returnCode = returnCode,
          fgColor = color)
      showOutput(message = $commandArguments, newLine = false,
          promptEnabled = false,
          previousCommand = commandName, returnCode = returnCode)
    except ValueError, IOError:
      discard

  # Start the shell
  while true:
    # Run only one command, don't show prompt and wait for the user input,
    # if there is still some data in last entered user input, also don't
    # ask for more.
    if not oneTimeCommand and inputString.len() == 0:
      # Write prompt
      showPrompt(promptEnabled = not oneTimeCommand,
          previousCommand = commandName, resultCode = returnCode)
      # Get the user input and parse it
      var inputChar: char = '\0'
      # Read the user input until not meet new line character or the input
      # reach the maximum length
      while inputChar.ord() != 13 and inputString.len() < maxInputLength:
        # Backspace pressed, delete the last character from the user input
        if inputChar.ord() == 127:
          keyWasArrow = false
          if inputString.len() > 0:
            try:
              inputString.setString(text = $inputString[0..^2])
              cursorPosition.dec()
            except CapacityError:
              discard
            try:
              stdout.cursorBackward()
              stdout.write(s = " ")
              stdout.cursorBackward()
            except ValueError, IOError:
              discard
        # Tab key pressed, do autocompletion if possible
        elif inputChar.ord() == 9:
          let
            spaceIndex: ExtendedNatural = inputString.rfind(sub = ' ')
            prefix: string = (if spaceIndex == -1: "" else: $inputString[
                spaceIndex + 1..^1])
            completion: string = getCompletion(prefix = prefix)
          if completion.len() > 0:
            try:
              stdout.cursorBackward(count = inputString.len() - spaceIndex - 1)
              stdout.write(s = completion)
              try:
                inputString.setString(text = inputString[0..spaceIndex] & completion)
              except CapacityError:
                discard
              cursorPosition = inputString.len()
            except ValueError, IOError:
              discard
        # Special keys pressed
        elif inputChar.ord() == 27:
          try:
            if getch() == '[':
              # Arrow up key pressed
              inputChar = getch()
              if inputChar == 'A' and historyIndex > 0:
                try:
                  inputString.setString(text = getHistory(
                      historyIndex = historyIndex, db = db,
                      searchFor = initLimitedString(capacity = maxInputLength,
                          text = (if keyWasArrow: "" else: $inputString))))
                except CapacityError:
                  discard
                cursorPosition = inputString.len()
                refreshInput()
                historyIndex.dec()
                if historyIndex < 1:
                  historyIndex = 1;
              # Arrow down key pressed
              elif inputChar == 'B' and historyIndex > 0:
                historyIndex.inc()
                let currentHistoryLength: HistoryRange = historyLength(db = db)
                if historyIndex > currentHistoryLength:
                  historyIndex = currentHistoryLength
                try:
                  inputString.setString(text = getHistory(
                      historyIndex = historyIndex, db = db,
                      searchFor = initLimitedString(capacity = maxInputLength,
                          text = (if keyWasArrow: "" else: $inputString))))
                except CapacityError:
                  discard
                cursorPosition = inputString.len()
                refreshInput()
              # Arrow left key pressed
              elif inputChar == 'D' and inputString.len() > 0 and
                  cursorPosition > 0:
                stdout.cursorBackward()
                cursorPosition.dec()
              # Arrow right key pressed
              elif inputChar == 'C' and inputString.len() > 0 and
                  cursorPosition < inputString.len():
                stdout.cursorForward()
                cursorPosition.inc()
              # Insert key pressed
              elif inputChar == '2' and getch() == '~':
                insertMode = not insertMode
              # Home key pressed
              elif inputChar == 'H' and cursorPosition > 0:
                stdout.cursorBackward(count = cursorPosition)
                cursorPosition = 0
              # End key pressed
              elif inputChar == 'F' and cursorPosition <= inputString.len():
                stdout.cursorForward(count = inputString.len() - cursorPosition)
                cursorPosition = inputString.len()
              keyWasArrow = true
          except ValueError, IOError:
            discard
        elif inputChar.ord() > 31:
          stdout.write(c = inputChar)
          if cursorPosition == inputString.len():
            try:
              inputString.add(y = inputChar)
            except CapacityError:
              discard
          elif insertMode:
            inputString[cursorPosition] = inputChar
          else:
            try:
              inputString.insert(item = $inputChar, i = cursorPosition)
              stdout.write(s = " ")
              stdout.cursorBackward(count = inputString.len() - cursorPosition)
            except ValueError, IOError, CapacityError:
              discard
          refreshInput()
          keyWasArrow = false
          cursorPosition.inc()
        try:
          inputChar = getch()
        except IOError:
          discard
      try:
        stdout.writeLine(x = "")
      except IOError:
        discard
    userInput = initOptParser(cmdLine = $inputString)
    # Reset the return code of the program
    returnCode = QuitSuccess.ResultCode
    # Go to the first token
    userInput.next()
    # If it looks like an argument, it must be command name
    if userInput.kind == cmdArgument:
      commandName = userInput.key
    # No command name, back to beginning
    if commandName == "":
      continue
    # Set the command arguments
    let arguments: UserInput = try:
        initLimitedString(capacity = maxInputLength, text = $getArguments(
            userInput = userInput, conjCommands = conjCommands))
      except CapacityError:
        emptyLimitedString(capacity = maxInputLength)
    try:
      inputString.setString(text = join(a = userInput.remainingArgs(), sep = " "))
    except CapacityError:
      discard
    # Parse commands
    case commandName
    # Quit from shell
    of "exit":
      historyIndex = updateHistory(commandToAdd = "exit", db = db)
      quitShell(returnCode = returnCode, db = db)
    # Show help screen
    of "help":
      returnCode = showHelp(topic = arguments, helpContent = helpContent, db = db)
    # Change current directory
    of "cd":
      returnCode = cdCommand(newDirectory = DirectoryPath($arguments),
          aliases = aliases, db = db)
      historyIndex = historyLength(db = db)
    # Set the environment variable
    of "set":
      returnCode = setCommand(arguments = arguments, db = db)
      historyIndex = historyLength(db = db)
    # Delete environment variable
    of "unset":
      returnCode = unsetCommand(arguments = arguments, db = db)
      historyIndex = historyLength(db = db)
    # Various commands related to environment variables
    of "variable":
      # No subcommand entered, show available options
      if arguments.len() == 0:
        historyIndex = helpVariables(db = db)
      # Show the list of declared environment variables
      elif arguments.startsWith(prefix = "list"):
        listVariables(arguments = arguments, historyIndex = historyIndex, db = db)
      # Delete the selected environment variable
      elif arguments.startsWith(prefix = "delete"):
        returnCode = deleteVariable(arguments = arguments,
            historyIndex = historyIndex, db = db)
      # Add a new variable
      elif arguments == "add":
        returnCode = addVariable(historyIndex = historyIndex, db = db)
      # Edit an existing variable
      elif arguments.startsWith(prefix = "edit"):
        returnCode = editVariable(arguments = arguments,
            historyIndex = historyIndex, db = db)
      else:
        try:
          returnCode = showUnknownHelp(subCommand = arguments,
              command = initLimitedString(capacity = 8, text = "variable"),
                  helpType = initLimitedString(capacity = 9,
                      text = "variables"))
          historyIndex = updateHistory(commandToAdd = "variable " & arguments,
              db = db, returnCode = returnCode)
        except CapacityError:
          returnCode = QuitFailure.ResultCode
    # Various commands related to the shell's commands' history
    of "history":
      # No subcommand entered, show available options
      if arguments.len() == 0:
        historyIndex = helpHistory(db = db)
      # Clear the shell's commands' history
      elif arguments == "clear":
        historyIndex = clearHistory(db = db)
      # Show the last executed shell's commands
      elif arguments.len() > 3 and arguments[0 .. 3] == "show":
        historyIndex = showHistory(db = db, arguments = arguments)
      else:
        try:
          returnCode = showUnknownHelp(subCommand = arguments,
              command = initLimitedString(capacity = 7, text = "history"),
                  helpType = initLimitedString(capacity = 7, text = "history"))
          historyIndex = updateHistory(commandToAdd = "history " & arguments,
              db = db, returnCode = returnCode)
        except CapacityError:
          returnCode = QuitFailure.ResultCode
    # Various commands related to the shell's options
    of "options":
      # No subcommand entered, show available options
      if arguments.len() == 0:
        helpOptions(db = db)
        historyIndex = updateHistory(commandToAdd = "options", db = db)
      # Show the list of available options
      elif arguments == "show":
        showOptions(db = db)
        historyIndex = updateHistory(commandToAdd = "options show", db = db)
      elif arguments.startsWith(prefix = "set"):
        returnCode = setOptions(arguments = arguments, db = db)
        historyIndex = updateHistory(commandToAdd = "options set", db = db,
            returnCode = returnCode)
        updateHelp(helpContent = helpContent, db = db)
      elif arguments.startsWith(prefix = "reset"):
        returnCode = resetOptions(arguments = arguments, db = db)
        historyIndex = updateHistory(commandToAdd = "options reset", db = db,
            returnCode = returnCode)
        updateHelp(helpContent = helpContent, db = db)
      else:
        try:
          returnCode = showUnknownHelp(subCommand = arguments,
              command = initLimitedString(capacity = 7, text = "options"),
                  helpType = initLimitedString(capacity = 7, text = "options"))
          historyIndex = updateHistory(commandToAdd = "options " & arguments,
              db = db, returnCode = returnCode)
        except CapacityError:
          returnCode = QuitFailure.ResultCode
    # Various commands related to the aliases (like show list of available
    # aliases, add, delete, edit them)
    of "alias":
      # No subcommand entered, show available options
      if arguments.len() == 0:
        historyIndex = helpAliases(db = db)
      # Show the list of available aliases
      elif arguments.startsWith(prefix = "list"):
        listAliases(arguments = arguments, historyIndex = historyIndex,
            aliases = aliases, db = db)
      # Delete the selected alias
      elif arguments.startsWith(prefix = "delete"):
        returnCode = deleteAlias(arguments = arguments,
            historyIndex = historyIndex, aliases = aliases, db = db)
      # Show the selected alias
      elif arguments.startsWith(prefix = "show"):
        returnCode = showAlias(arguments = arguments,
            historyIndex = historyIndex, aliases = aliases, db = db)
      # Add a new alias
      elif arguments.startsWith(prefix = "add"):
        returnCode = addAlias(historyIndex = historyIndex, aliases = aliases, db = db)
      # Add a new alias
      elif arguments.startsWith(prefix = "edit"):
        returnCode = editAlias(arguments = arguments,
            historyIndex = historyIndex, aliases = aliases, db = db)
      else:
        try:
          returnCode = showUnknownHelp(subCommand = arguments,
              command = initLimitedString(capacity = 5, text = "alias"),
                  helpType = initLimitedString(capacity = 7, text = "aliases"))
          historyIndex = updateHistory(commandToAdd = "alias " & arguments,
              db = db, returnCode = returnCode)
        except CapacityError:
          returnCode = QuitFailure.ResultCode
    # Execute external command or alias
    else:
      let commandToExecute: string = commandName & (if arguments.len() >
          0: " " & arguments else: "")
      try:
        # Check if command is an alias, if yes, execute it
        if initLimitedString(capacity = maxInputLength, text = commandName) in aliases:
          returnCode = execAlias(arguments = arguments, aliasId = commandName,
              aliases = aliases, db = db)
          historyIndex = updateHistory(commandToAdd = commandToExecute, db = db,
              returnCode = returnCode)
          cursorPosition = inputString.len()
        else:
          # Execute external command
          returnCode = ResultCode(execCmd(command = commandToExecute))
          historyIndex = updateHistory(commandToAdd = commandToExecute, db = db,
              returnCode = returnCode)
      except CapacityError:
        returnCode = QuitFailure.ResultCode
    # If there is more commands to execute check if the next commands should
    # be executed. if the last command wasn't success and commands conjuncted
    # with && or the last command was success and command disjuncted, reset
    # the input, don't execute more commands.
    if inputString.len() > 0 and ((returnCode != QuitSuccess and
        conjCommands) or (returnCode == QuitSuccess and not conjCommands)):
      inputString = emptyLimitedString(capacity = maxInputLength)
    # Run only one command, quit from the shell
    if oneTimeCommand and inputString.len() == 0:
      quitShell(returnCode = returnCode, db = db)
    cursorPosition = inputString.len()

when isMainModule:
  main()
