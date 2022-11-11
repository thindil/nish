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

# Standard library imports
import std/[db_sqlite, os, osproc, parseopt, strutils, tables, terminal, unicode]
# External modules imports
import contracts
# Internal imports
import aliases, commands, commandslist, completion, constants, directorypath,
    help, highlight, history, input, lstring, options, output, plugins, prompt,
    resultcode, title, variables

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
    Nish version: 0.5.0

    Copyright: 2021-2022 Bartek Jasicki <thindil@laeran.pl>
    License: 3-Clause BSD""")
    stdout.flushFile()
  except IOError:
    quit QuitFailure
  quit QuitSuccess

proc quitShell*(returnCode: ResultCode; db: DbConn) {.gcsafe, sideEffect,
    raises: [], tags: [DbEffect, WriteIOEffect, ReadEnvEffect, TimeEffect],
    contractual.} =
  ## FUNCTION
  ##
  ## Close the shell database and quit from the program with the selected return code
  ##
  ## PARAMETERS
  ##
  ## * returnCode - the exit code to return with the end of the program
  ## * db         - the connection to the shell's database
  require:
    db != nil
  body:
    try:
      db.close()
    except DbError:
      quit showError(message = "Can't close properly the shell database. Reason:",
          e = getCurrentException()).int
    quit int(returnCode)

proc startDb*(dbPath: DirectoryPath): DbConn {.sideEffect, raises: [], tags: [
    ReadIOEffect, WriteDirEffect, DbEffect, WriteIOEffect, ReadEnvEffect,
    TimeEffect, RootEffect], contractual.} =
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
  require:
    dbPath.len() > 0
  body:
    try:
      discard existsOrCreateDir(dir = parentDir(path = $dbPath))
    except OSError, IOError:
      showError(message = "Can't create directory for the shell's database. Reason: ",
          e = getCurrentException())
      return nil
    let dbExists: bool = fileExists($dbPath)
    try:
      result = open(connection = $dbPath, user = "", password = "", database = "")
    except DbError:
      showError(message = "Can't open the shell's database. Reason: ",
          e = getCurrentException())
      return nil
    let
      versionName: OptionName = try:
          initLimitedString(capacity = 9, text = "dbVersion")
        except CapacityError:
          showError(message = "Can't set versionName. Reason: ",
              e = getCurrentException())
          return nil
      versionValue: OptionValue = try:
          initLimitedString(capacity = 1, text = "3")
        except CapacityError:
          showError(message = "Can't set versionValue. Reason: ",
              e = getCurrentException())
          return nil
      promptName: OptionName = try:
          initLimitedString(capacity = 13, text = "promptCommand")
        except CapacityError:
          showError(message = "Can't set promptName. Reason: ",
              e = getCurrentException())
          return nil
      promptValue: OptionValue = try:
          initLimitedString(capacity = 8, text = "built-in")
        except CapacityError:
          showError(message = "Can't set promptValue. Reason: ",
              e = getCurrentException())
          return nil
      titleName: OptionName = try:
          initLimitedString(capacity = 8, text = "setTitle")
        except CapacityError:
          showError(message = "Can't set setTitle. Reason: ",
              e = getCurrentException())
          return nil
      trueValue: OptionValue = try:
          initLimitedString(capacity = 4, text = "true")
        except CapacityError:
          showError(message = "Can't set trueValue. Reason: ",
              e = getCurrentException())
          return nil
      syntaxName: OptionName = try:
          initLimitedString(capacity = 11, text = "colorSyntax")
        except CapacityError:
          showError(message = "Can't set colorSyntax. Reason: ",
              e = getCurrentException())
          return nil
    # Create a new database if not exists
    if not dbExists:
      if createAliasesDb(db = result) == QuitFailure:
        return nil
      if createOptionsDb(db = result) == QuitFailure:
        return nil
      if createHistoryDb(db = result) == QuitFailure:
        return nil
      if createVariablesDb(db = result) == QuitFailure:
        return nil
      if createPluginsDb(db = result) == QuitFailure:
        return nil
      if createHelpDb(db = result) == QuitFailure:
        return nil
      try:
        setOption(optionName = versionName, value = versionValue,
            description = initLimitedString(capacity = 43,
            text = "Version of the database schema (read only)."),
            valueType = ValueType.natural, db = result, readOnly = 1)
        setOption(optionName = promptName, value = promptValue,
            description = initLimitedString(capacity = 61,
            text = "The command which output will be used as the prompt of shell."),
            valueType = ValueType.command, db = result, readOnly = 0)
        setOption(optionName = titleName, value = trueValue,
            description = initLimitedString(capacity = 50,
            text = "Set a terminal title to currently running command."),
            valueType = ValueType.boolean, db = result, readOnly = 0)
        setOption(optionName = syntaxName, value = trueValue,
            description = initLimitedString(capacity = 69,
            text = "Color the user input with info about invalid commands, quotes, etc."),
            valueType = ValueType.boolean, db = result, readOnly = 0)
      except CapacityError:
        showError(message = "Can't set database schema. Reason: ",
            e = getCurrentException())
        return nil
    # If database version is different than the newest, update database
    try:
      case parseInt(s = $getOption(optionName = versionName, db = result,
          defaultValue = initLimitedString(capacity = 1, text = "0")))
      of 0 .. 1:
        if updateOptionsDb(db = result) == QuitFailure:
          return nil
        if updateHistoryDb(db = result) == QuitFailure:
          return nil
        if updateAliasesDb(db = result) == QuitFailure:
          return nil
        if createPluginsDb(db = result) == QuitFailure:
          return nil
        if createHelpDb(db = result) == QuitFailure:
          return nil
        setOption(optionName = versionName, value = versionValue,
            description = initLimitedString(capacity = 43,
            text = "Version of the database schema (read only)."),
            valueType = ValueType.natural, db = result)
        setOption(optionName = promptName, value = promptValue,
            description = initLimitedString(capacity = 60,
            text = "The command which output will be used as the shell's prompt."),
            valueType = ValueType.command, db = result, readOnly = 0)
      of 2:
        if updatePluginsDb(db = result) == QuitFailure:
          return nil
        setOption(optionName = versionName, value = versionValue, db = result)
        setOption(optionName = titleName, value = trueValue,
            description = initLimitedString(capacity = 50,
            text = "Set a terminal title to currently running command."),
            valueType = ValueType.boolean, db = result, readOnly = 0)
        setOption(optionName = syntaxName, value = trueValue,
            description = initLimitedString(capacity = 69,
            text = "Color the user's input with info about invalid commands, quotes, etc."),
            valueType = ValueType.boolean, db = result, readOnly = 0)
      of 3:
        discard
      else:
        showError(message = "Invalid version of database.")
        return nil
    except CapacityError, DbError, ValueError:
      showError(message = "Can't update database. Reason: ",
          e = getCurrentException())
      return nil

proc main() {.sideEffect, raises: [], tags: [ReadIOEffect, WriteIOEffect,
    ExecIOEffect, RootEffect].} =
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
    aliases = newOrderedTable[AliasName, int]()
    dbPath: DirectoryPath = DirectoryPath(getConfigDir() & DirSep & "nish" &
        DirSep & "nish.db")
    cursorPosition: Natural = 0
    commands = newTable[string, CommandData]()

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
          inputString.text = options.key
        except CapacityError:
          quit showError(message = "The entered command is too long.").int
      of "h", "help":
        showCommandLineHelp()
      of "v", "version":
        showProgramVersion()
      of "db":
        dbPath = options.val.DirectoryPath
    else:
      discard

  # Connect to the shell database
  let db: DbConn = startDb(dbPath = dbPath)

  # Stop shell if connection to its database was unsuccesful
  if db == nil:
    quit QuitFailure

  # Initialize the shell's commands history
  historyIndex = initHistory(db = db, commands = commands)

  # Initialize the shell's options system
  initOptions(commands = commands)

  # Initialize the shell's aliases system
  initAliases(db = db, aliases = aliases, commands = commands)

  # Initialize the shell's environment variables system
  initVariables(db = db, commands = commands)

  # Set the shell's help
  initHelp(db = db, commands = commands)

  # Initialize the shell's plugins system
  initPlugins(db = db, commands = commands)

  # Set the title of the terminal to current directory
  setTitle(title = $getFormattedDir(), db = db)

  # Start the shell
  while true:
    # Write the shell's prompt and get the input from the user, only when the
    # shell's didn't start in one command mode and there is no remaining the
    # user input to parse
    if not oneTimeCommand and inputString.len() == 0:
      # Write prompt
      let promptLength: Natural = showPrompt(promptEnabled = not oneTimeCommand,
          previousCommand = commandName, resultCode = returnCode, db = db)
      # Get the user input and parse it
      var inputChar: char = '\0'
      # Read the user input until not meet new line character or the input
      # reach the maximum length
      while inputChar.ord() != 13 and inputString.len() < maxInputLength:
        # Get the character from the user's input
        try:
          inputChar = getch()
        except IOError:
          showError(message = "Can't get the entered character. Reason: ",
              e = getCurrentException())
        # Backspace pressed, delete the character before cursor from the user
        # input
        if inputChar.ord() == 127:
          keyWasArrow = false
          if cursorPosition == 0:
            continue
          deleteChar(inputString = inputString, cursorPosition = cursorPosition)
          highlightOutput(promptLength = promptLength,
              inputString = inputString, commands = commands, aliases = aliases,
              oneTimeCommand = oneTimeCommand, commandName = $commandName,
              returnCode = returnCode, db = db, cursorPosition = cursorPosition)
        # Tab key pressed, do autocompletion if possible
        elif inputChar.ord() == 9:
          let
            spaceIndex: ExtendedNatural = inputString.rfind(sub = ' ')
            prefix: string = (if spaceIndex ==
                -1: $inputString else: $inputString[spaceIndex + 1..^1])
            completion: string = getCompletion(prefix = prefix)
          if completion.len() == 0:
            continue
          try:
            stdout.cursorBackward(count = runeLen(s = $inputString) -
                spaceIndex - 1)
            stdout.write(s = completion)
            inputString.text = inputString[0..spaceIndex] & completion
            cursorPosition = runeLen(s = $inputString)
          except IOError:
            discard
          except ValueError:
            showError(message = "Invalid value for character position.",
                e = getCurrentException())
          except CapacityError:
            showError(message = "Entered input is too long.",
                e = getCurrentException())
        # Special keys pressed
        elif inputChar.ord() == 27:
          try:
            if getch() in ['[', 'O']:
              inputChar = getch()
              # Arrow up key pressed
              if inputChar == 'A' and historyIndex > 0:
                try:
                  inputString.text = getHistory(
                      historyIndex = historyIndex, db = db,
                      searchFor = initLimitedString(capacity = maxInputLength,
                          text = (if keyWasArrow: "" else: $inputString)))
                except CapacityError:
                  showError(message = "Entered input is too long.",
                      e = getCurrentException())
                cursorPosition = runeLen(s = $inputString)
                highlightOutput(promptLength = promptLength,
                    inputString = inputString, commands = commands,
                    aliases = aliases, oneTimeCommand = oneTimeCommand,
                    commandName = $commandName, returnCode = returnCode,
                    db = db, cursorPosition = cursorPosition)
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
                  inputString.text = getHistory(
                      historyIndex = historyIndex, db = db,
                      searchFor = initLimitedString(capacity = maxInputLength,
                          text = (if keyWasArrow: "" else: $inputString)))
                except CapacityError:
                  showError(message = "Entered input is too long.",
                      e = getCurrentException())
                cursorPosition = runeLen(s = $inputString)
                highlightOutput(promptLength = promptLength,
                    inputString = inputString, commands = commands,
                    aliases = aliases, oneTimeCommand = oneTimeCommand,
                    commandName = $commandName, returnCode = returnCode,
                    db = db, cursorPosition = cursorPosition)
              # Arrow left key pressed
              elif inputChar == 'D' and cursorPosition > 0:
                stdout.cursorBackward()
                cursorPosition.dec()
              # Arrow right key pressed
              elif inputChar == 'C' and cursorPosition < runeLen(
                  s = $inputString):
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
              elif inputChar == 'F' and cursorPosition < runeLen(
                  s = $inputString):
                stdout.cursorForward(count = runeLen(s = $inputString) - cursorPosition)
                cursorPosition = runeLen(s = $inputString)
              keyWasArrow = true
          except IOError:
            discard
          except ValueError:
            showError(message = "Invalid value for moving cursor.",
                e = getCurrentException())
        # Ctrl-c pressed, cancel current command and return 130 result code
        elif inputChar.ord() == 3:
          inputString = emptyLimitedString(capacity = maxInputLength)
          returnCode = 130.ResultCode
          cursorPosition = 0
          commandName = "ctrl-c"
          break
        # Any graphical character pressed, show it in the input field
        elif inputChar.ord() > 31:
          let inputRune: string = readChar(inputChar = inputChar)
          if cursorPosition < runeLen(s = $inputString):
            if insertMode:
              var runes = toRunes(s = $inputString)
              runes[cursorPosition] = inputRune.toRunes()[0]
              try:
                inputString.text = $runes
              except CapacityError:
                showError(message = "Entered input is too long.",
                    e = getCurrentException())
            else:
              var runes = toRunes(s = $inputString)
              runes.insert(item = inputRune.toRunes()[0], i = cursorPosition)
              try:
                inputString.text = $runes
                cursorPosition.inc()
              except CapacityError:
                showError(message = "Entered input is too long.",
                    e = getCurrentException())
          else:
            try:
              inputString.add(y = inputRune)
              cursorPosition.inc()
            except CapacityError:
              showError(message = "Entered input is too long.",
                  e = getCurrentException())
          highlightOutput(promptLength = promptLength,
              inputString = inputString, commands = commands,
              aliases = aliases, oneTimeCommand = oneTimeCommand,
              commandName = $commandName, returnCode = returnCode,
              db = db, cursorPosition = cursorPosition)
          keyWasArrow = false
      try:
        stdout.writeLine(x = "")
      except IOError:
        discard
    # User just press Enter key, reset return code (if user doesn't pressed
    # ctrl-c) and back to beginning
    if inputString.len() == 0:
      if returnCode != 130:
        returnCode = QuitSuccess.ResultCode
      continue
    userInput = initOptParser(cmdLine = $inputString)
    # Reset the return code of the program
    returnCode = QuitSuccess.ResultCode
    # Go to the first token
    userInput.next()
    # If it looks like an argument, it must be command name
    if userInput.kind == cmdArgument:
      commandName = userInput.key
    # Set the command arguments
    let arguments: UserInput = try:
        initLimitedString(capacity = maxInputLength, text = $getArguments(
            userInput = userInput, conjCommands = conjCommands))
      except CapacityError:
        emptyLimitedString(capacity = maxInputLength)
    try:
      inputString.text = join(a = userInput.remainingArgs(), sep = " ")
    except CapacityError:
      showError(message = "Entered input is too long.", e = getCurrentException())
    # Set a terminal title to current command
    setTitle(title = commandName, db = db)
    # Execute plugins with precommand hook
    try:
      for plugin in db.fastRows(query = sql(
          query = "SELECT location FROM plugins WHERE precommand=1")):
        discard execPlugin(pluginPath = plugin[0], arguments = ["preCommand",
            commandName & " " & arguments], db = db, commands = commands)
    except DbError:
      showError(message = "Can't execute preCommand hook for plugins. Reason: ",
          e = getCurrentException())
    # Parse commands
    case commandName
    # Quit from shell
    of "exit":
      historyIndex = updateHistory(commandToAdd = "exit", db = db)
      try:
        setTitle(title = getCurrentDir(), db = db)
      except OSError:
        setTitle(title = "nish", db = db)
      quitShell(returnCode = returnCode, db = db)
    # Change current directory
    of "cd":
      returnCode = cdCommand(newDirectory = DirectoryPath($arguments),
          aliases = aliases, db = db)
    # Set the environment variable
    of "set":
      returnCode = setCommand(arguments = arguments)
    # Delete environment variable
    of "unset":
      returnCode = unsetCommand(arguments = arguments)
    # Execute command (the shell's or external) or the shell's alias
    else:
      # Check if command is the shell's command, if yes, execute it
      if commands.hasKey(key = commandName):
        try:
          # Build-in shell's command
          if commands[commandName].command != nil:
            returnCode = commands[commandName].command(arguments = arguments,
                db = db, list = CommandLists(aliases: aliases,
                commands: commands))
          # The shell's command from plugin
          else:
            let returnValues = execPlugin(pluginPath = commands[
                commandName].plugin, arguments = [commandName, $arguments],
                db = db, commands = commands)
            returnCode = returnValues.code
        except KeyError:
          showError(message = "Can't execute command '" & commandName &
              "'. Reason: ", e = getCurrentException())
      else:
        let commandToExecute: string = commandName & (if arguments.len() >
            0: " " & arguments else: "")
        try:
          # Check if command is an alias, if yes, execute it
          if initLimitedString(capacity = maxInputLength, text = commandName) in aliases:
            returnCode = execAlias(arguments = arguments, aliasId = commandName,
                aliases = aliases, db = db)
            cursorPosition = runeLen(s = $inputString)
          else:
            # Execute external command
            returnCode = ResultCode(execCmd(command = commandToExecute))
        except CapacityError:
          returnCode = QuitFailure.ResultCode
    # Update the shell's history with info about the executed command
    historyIndex = updateHistory(commandToAdd = commandName & (if arguments.len(
      ) > 0: " " & arguments else: ""), db = db, returnCode = returnCode)
    # Restore the terminal title
    setTitle(title = $getFormattedDir(), db = db)
    # Execute plugins with postcommand hook
    try:
      for plugin in db.fastRows(query = sql(
          query = "SELECT location FROM plugins WHERE postcommand=1")):
        discard execPlugin(pluginPath = plugin[0], arguments = ["postCommand",
            commandName & " " & arguments], db = db, commands = commands)
    except DbError:
      showError(message = "Can't execute postCommand hook for plugins. Reason: ",
          e = getCurrentException())
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
    cursorPosition = runeLen(s = $inputString)

when isMainModule:
  main()
