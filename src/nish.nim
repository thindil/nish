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
import std/[db_sqlite, os, osproc, parseopt, strutils, tables, terminal]
# External modules imports
import contracts
# Internal imports
import aliases, commands, commandslist, completion, constants, directorypath,
    help, history, input, lstring, options, output, plugins, prompt, resultcode, variables

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
    Nish version: 0.4.0

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

proc startDb*(dbPath: DirectoryPath): DbConn {.gcsafe, sideEffect, raises: [],
    tags: [ReadIOEffect, WriteDirEffect, DbEffect, WriteIOEffect, ReadEnvEffect,
    TimeEffect], contractual.} =
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
          initLimitedString(capacity = 1, text = "2")
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
            valueType = ValueType.command, db = result, readOnly = 1)
      except CapacityError:
        showError(message = "Can't set database schema. Reason: ",
            e = getCurrentException())
        return nil
    # If database version is different than the newest, update database
    try:
      if parseInt(s = $getOption(optionName = versionName, db = result,
          defaultValue = initLimitedString(capacity = 1, text = "0"))) <
              parseInt(s = $versionValue):
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
            valueType = ValueType.command, db = result, readOnly = 1)
    except CapacityError, DbError, ValueError:
      showError(message = "Can't update database. Reason: ",
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
    aliases = newOrderedTable[AliasName, int]()
    dbPath: DirectoryPath = DirectoryPath(getConfigDir() & DirSep & "nish" &
        DirSep & "nish.db")
    helpContent = newTable[string, HelpEntry]()
    cursorPosition: Natural = 0
    plugins = newTable[string, PluginData]()
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
  historyIndex = initHistory(db = db, helpContent = helpContent,
      commands = commands)

  # Initialize the shell's options system
  initOptions(helpContent = helpContent, commands = commands)

  # Initialize the shell's aliases system
  initAliases(helpContent = helpContent, db = db, aliases = aliases,
      commands = commands)

  # Initialize the shell's build-in commands
  initCommands(helpContent = helpContent)

  # Initialize the shell's environment variables system
  initVariables(helpContent = helpContent, db = db, commands = commands)

  # Set the shell's help
  initHelp(helpContent = helpContent, db = db, commands = commands)

  # Initialize the shell's prompt system
  initPrompt(helpContent = helpContent)

  # Initialize the shell's plugins system
  initPlugins(helpContent = helpContent, db = db, pluginsList = plugins,
      commands = commands)

  # Set the main help screen for the shell
  setMainHelp(helpContent = helpContent)

  proc refreshOutput(multiLine: bool) {.gcsafe, sideEffect, raises: [], tags: [
      WriteIOEffect, ReadIOEffect, ReadDbEffect, TimeEffect, RootEffect].} =
    ## FUNCTION
    ##
    ## Refresh the user input, clear the old and show the new. Color the entered
    ## command on green if it is valid or red if invalid
    ##
    ## PARAMETERS
    ##
    ## * multiLine - If true, then the shell's prompt is made of many lines and
    ##               don't refresh it
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
        # Built-in commands
        if $command in ["exit", "cd", "set", "unset"]:
          color = fgGreen
        # The shell's commands
        elif commands.hasKey(key = $command):
          color = fgGreen
        # Aliases
        elif aliases.contains(key = command):
          color = fgGreen
      if not multiLine:
        showPrompt(promptEnabled = not oneTimeCommand,
            previousCommand = $commandName, resultCode = returnCode, db = db)
      showOutput(message = $command, newLine = false, fgColor = color)
      showOutput(message = $commandArguments, newLine = false)
      if cursorPosition < input.len() - 1:
        stdout.cursorBackward(count = input.len() - cursorPosition - 1)
    except ValueError, IOError:
      discard

  # Start the shell
  while true:
    # Run only one command, don't show prompt and wait for the user input,
    # if there is still some data in last entered user input, also don't
    # ask for more.
    if not oneTimeCommand and inputString.len() == 0:
      # Write prompt
      let multiLine: bool = showPrompt(promptEnabled = not oneTimeCommand,
          previousCommand = commandName, resultCode = returnCode, db = db)
      # Get the user input and parse it
      var inputChar: char = '\0'
      # Read the user input until not meet new line character or the input
      # reach the maximum length
      while inputChar.ord() != 13 and inputString.len() < maxInputLength:
        # Backspace pressed, delete the character before cursor from the user
        # input
        if inputChar.ord() == 127:
          keyWasArrow = false
          if inputString.len() > 0:
            try:
              if cursorPosition == inputString.len():
                inputString.setString(text = $inputString[0..^2])
                try:
                  stdout.cursorBackward()
                  stdout.write(s = " ")
                  stdout.cursorBackward()
                except ValueError, IOError:
                  discard
                cursorPosition.dec()
              elif cursorPosition > 0:
                inputString.setString(text = $inputString[0..cursorPosition -
                    2] & $inputString[cursorPosition..inputString.len() - 1])
                refreshOutput(multiLine)
                try:
                  stdout.cursorBackward(count = inputString.len() - cursorPosition)
                except ValueError, IOError:
                  discard
                cursorPosition.dec()
            except CapacityError:
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
                refreshOutput(multiLine)
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
                refreshOutput(multiLine)
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
        # Ctrl-c pressed, cancel current command and return 130 result code
        elif inputChar.ord() == 3:
          inputString = emptyLimitedString(capacity = maxInputLength)
          returnCode = 130.ResultCode
          cursorPosition = 0
          commandName = "ctrl-c"
          break
        # Any graphical character pressed, show it in the input field
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
          refreshOutput(multiLine)
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
      inputString.setString(text = join(a = userInput.remainingArgs(), sep = " "))
    except CapacityError:
      discard
    # Execute plugins with precommand hook
    for plugin in plugins.values:
      if "preCommand" in plugin.api:
        discard execPlugin(pluginPath = plugin.path, arguments = ["preCommand",
            commandName & " " & arguments], db = db, commands = commands)
    # Parse commands
    case commandName
    # Quit from shell
    of "exit":
      historyIndex = updateHistory(commandToAdd = "exit", db = db)
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
                db = db, list = CommandLists(help: helpContent,
                    aliases: aliases, plugins: plugins, commands: commands))
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
            cursorPosition = inputString.len()
          else:
            # Execute external command
            returnCode = ResultCode(execCmd(command = commandToExecute))
        except CapacityError:
          returnCode = QuitFailure.ResultCode
    # Update the shell's history with info about the executed command
    historyIndex = updateHistory(commandToAdd = commandName & (if arguments.len(
      ) > 0: " " & arguments else: ""), db = db, returnCode = returnCode)
    # Execute plugins with postcommand hook
    for plugin in plugins.values:
      if "postCommand" in plugin.api:
        discard execPlugin(pluginPath = plugin.path, arguments = ["postCommand",
            commandName & " " & arguments], db = db, commands = commands)
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
