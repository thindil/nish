# Copyright © 2021-2024 Bartek Jasicki
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

## The main module of the shell. Contains code for command line options, starting,
## and stopping the shell and the main loop of the shell itself.

# Standard library imports
import std/[os, osproc, paths, parseopt, strutils, tables, terminal, unicode]
when compileOption(option = "profiler"):
  import nimprof
# External modules imports
import ansiparse, contracts, nancy, termstyle
import norm/sqlite
# Internal imports
import aliases, commands, commandslist, completion, constants, db, help,
    highlight, history, input, logger, options, output, plugins, prompt,
    suggestion, theme, themeinit, title, types, variables

proc showCommandLineHelp*() {.sideEffect, raises: [], tags: [WriteIOEffect],
    contractual.} =
  ## Show the program arguments help
  ##
  ## Return QuitSuccess when the program's arguments help was shown, otherwise
  ## QuitFailure.
  body:
    try:
      stdout.writeLine(x = """Available arguments are:
      -c [command]  - Run the selected command in shell and quit
      --db [path]   - Set the shell database to the selected file
      -h, --help    - Show this help and quit
      -v, --version - Show the shell version info""")
      stdout.flushFile
    except IOError:
      when isMainModule:
        quit QuitFailure
    when isMainModule:
      quit QuitSuccess

proc showProgramVersion*() {.sideEffect, raises: [], tags: [WriteIOEffect],
    contractual.} =
  ## Show the program version
  ##
  ## Returns QuitSuccess when the program's arguments help was shown, otherwise
  ## QuitFailure.
  body:
    try:
      stdout.writeLine(x = """
      Nish version: """ & version & """

      Copyright: 2021-2024 Bartek Jasicki <thindil@laeran.pl.eu.org>
      License: 3-Clause BSD""")
      stdout.flushFile
    except IOError:
      when isMainModule:
        quit QuitFailure
    when isMainModule:
      quit QuitSuccess

proc readUserInput*(inputString: var UserInput; oneTimeCommand: bool;
    db: DbConn; commandName: var string; returnCode: var ResultCode;
    historyIndex: var HistoryRange; cursorPosition: var Natural;
    aliases: ref OrderedTable[AliasName, int]; commands: ref Table[string,
    CommandData]) {.raises: [], tags: [WriteIOEffect, ReadEnvEffect,
    ReadDirEffect, TimeEffect, DbEffect, ReadIOEffect, RootEffect],
    contractual.} =
  ## Handle the user's input, show the shell's prompt, tab completion and
  ## highglight the input if needed
  ##
  ## * inputString    - the text entered by the user, after processing, with
  ##                    syntax highlightning, read from shell's history, etc.
  ## * oneTimeCommand - if true, the shell will quit after executing the user's
  ##                    command
  ## * db             - the connection to the shell's database
  ## * commandName    - the user's last command name
  ## * returnCode     - the return code of the user's last command
  ## * historyIndex   - the index of the command in the shell's history
  ## * cursorPosition - the current vertical position of the cursor on the screen
  ## * aliases        - the list of the shell's aliases
  ## * commands       - the list of the shell's commands
  require:
    db != nil
    commands != nil
    aliases != nil
  body:
    # Write prompt
    var promptLength: Natural = showPrompt(
        promptEnabled = not oneTimeCommand, previousCommand = commandName,
        resultCode = returnCode, db = db)
    # Get the user input and parse it
    let highlightEnabled: bool =
      getOption(optionName = "colorSyntax", db = db, defaultValue = "true") == "true"
    var
      inputChar: char = '\0'
      completions: seq[string] = @[]
      completionWidth: seq[Natural] = @[]
      currentCompletion: Natural = 0
      keyWasArrow, insertMode, completionMode: bool = false
    # Read the user input until not meet new line character or the input
    # reach the maximum length
    while inputChar.ord != 13 and inputString.len < maxInputLength:
      # Get the character from the user's input
      try:
        inputChar = getch()
      except IOError:
        # If there is a problem with input/output, quit the shell or it
        # will be stuck in endless loop. Later it should be replaced by
        # more elegant solution.
        closeDb(returnCode = QuitFailure.ResultCode, db = db)
      case inputChar.ord
      # Backspace pressed, delete the character before cursor from the user
      # input
      of 8, 127:
        keyWasArrow = false
        if cursorPosition == 0:
          continue
        deleteChar(inputString = inputString,
            cursorPosition = cursorPosition)
        highlightOutput(promptLength = promptLength,
            inputString = inputString, commands = commands,
            aliases = aliases, oneTimeCommand = oneTimeCommand,
            commandName = $commandName, returnCode = returnCode, db = db,
            cursorPosition = cursorPosition, enabled = highlightEnabled)
      # Tab key pressed, do autocompletion if possible
      of 9:
        let
          spaceIndex: ExtendedNatural = inputString.rfind(sub = ' ')
          prefix: string = (if spaceIndex ==
              -1: $inputString else: $inputString[spaceIndex + 1..^1])
        completions = @[]
        getDirCompletion(prefix = prefix, completions = completions, db = db)
        if inputString.startsWith(prefix = prefix) and (spaceIndex == -1 or
            spaceIndex >= cursorPosition):
          getCommandCompletion(prefix = prefix, completions = completions,
              aliases = aliases, commands = commands, db = db)
        elif spaceIndex > -1:
          getCompletion(commandName = $inputString[0 .. spaceIndex - 1],
              prefix = prefix, completions = completions, aliases = aliases,
                  commands = commands, db = db)
        if completions.len == 0:
          continue
        elif completions.len == 1:
          try:
            stdout.cursorBackward(count = runeLen(s = $inputString) -
                spaceIndex - 1)
            stdout.write(s = completions[0])
            inputString = inputString[0..spaceIndex] & completions[0]
            cursorPosition = runeLen(s = $inputString)
          except IOError, OSError:
            discard
          except ValueError:
            showError(message = "Invalid value for character position.",
                e = getCurrentException(), db = db)
        else:
          try:
            let columnsAmount: int = try:
                parseInt(s = $getOption(optionName = "completionColumns",
                    db = db, defaultValue = "5"))
              except ValueError:
                5
            # If Tab pressed the first time, show the list of completion
            if not completionMode:
              stdout.writeLine(x = "")
              let color: string = getColor(db = db, name = completionList)
              var
                table: TerminalTable = TerminalTable()
                row: seq[string] = @[]
                amount, line: Natural = 0
              for completion in completions:
                row.add(y = style(ss = completion, style = color))
                amount.inc
                if amount == columnsAmount:
                  try:
                    table.add(parts = row)
                  except UnknownEscapeError, InsufficientInputError, FinalByteError:
                    showError(message = "Can't show Tab completion. Reason: ",
                        e = getCurrentException(), db = db)
                  row = @[]
                  amount = 0
                  line.inc
              if amount > 0 and amount < columnsAmount:
                try:
                  table.add(parts = row)
                except UnknownEscapeError, InsufficientInputError, FinalByteError:
                  showError(message = "Can't show Tab completion. Reason: ",
                      e = getCurrentException(), db = db)
                line.inc
              completionWidth = @[]
              for column in table.getColumnSizes(maxSize = terminalWidth()):
                completionWidth.add(y = column + 4)
              try:
                table.echoTable(padding = 4)
              except IOError, Exception:
                showError(message = "Can't show Tab completion. Reason: ",
                    e = getCurrentException(), db = db)
              stdout.cursorUp(count = line)
              completionMode = true
              currentCompletion = 0
              stdout.cursorBackward(count = terminalWidth())
              continue
            # Select the next completion from the list
            currentCompletion.inc
            # Return to the first completion if reached the end of the list
            if currentCompletion == completions.len:
              let line: int = completions.len div columnsAmount
              if line > 0 and completions.len > columnsAmount:
                stdout.cursorUp(count = line)
              stdout.cursorBackward(count = terminalWidth())
              currentCompletion = 0
              continue
            # Go to the next line if the last completion in the line reached
            if currentCompletion mod columnsAmount == 0:
              stdout.cursorDown
              stdout.cursorBackward(count = terminalWidth())
              continue
            # Move cursor to the next completion
            stdout.cursorForward(count = completionWidth[(
                currentCompletion - 1) mod columnsAmount])
          except IOError, ValueError, OSError:
            discard
      # Special keys pressed
      of 27:
        try:
          if getch() in ['[', 'O']:
            inputChar = getch()
            # Arrow up key pressed
            case inputChar
            of 'A':
              if historyIndex == 0:
                continue
              inputString = getHistory(historyIndex = historyIndex,
                  db = db, searchFor = (
                  if keyWasArrow: "" else: $inputString))
              cursorPosition = runeLen(s = $inputString)
              highlightOutput(promptLength = promptLength,
                  inputString = inputString, commands = commands,
                  aliases = aliases, oneTimeCommand = oneTimeCommand,
                  commandName = $commandName, returnCode = returnCode,
                  db = db, cursorPosition = cursorPosition,
                  enabled = highlightEnabled)
              historyIndex.dec
              if historyIndex < 1:
                historyIndex = 1;
            # Arrow down key pressed
            of 'B':
              if historyIndex == 0:
                continue
              historyIndex.inc
              let currentHistoryLength: HistoryRange = historyLength(db = db)
              if historyIndex > currentHistoryLength:
                historyIndex = currentHistoryLength
              inputString = getHistory(historyIndex = historyIndex,
                  db = db, searchFor = (
                  if keyWasArrow: "" else: $inputString))
              cursorPosition = runeLen(s = $inputString)
              highlightOutput(promptLength = promptLength,
                  inputString = inputString, commands = commands,
                  aliases = aliases, oneTimeCommand = oneTimeCommand,
                  commandName = $commandName, returnCode = returnCode,
                  db = db, cursorPosition = cursorPosition,
                  enabled = highlightEnabled)
            # Insert key pressed
            of '2':
              if getch() == '~':
                insertMode = not insertMode
            # Delete key pressed
            of '3':
              if getch() == '~':
                if cursorPosition == runeLen(s = $inputString):
                  continue
                cursorPosition.inc
                deleteChar(inputString = inputString,
                    cursorPosition = cursorPosition)
                highlightOutput(promptLength = promptLength,
                    inputString = inputString, commands = commands,
                    aliases = aliases, oneTimeCommand = oneTimeCommand,
                    commandName = $commandName, returnCode = returnCode,
                    db = db,
                    cursorPosition = cursorPosition, enabled = highlightEnabled)
            # Move cursor if the proper key was pressed (arrows, home, end)
            # if not in completion mode
            else:
              if not completionMode:
                moveCursor(inputChar = inputChar,
                    cursorPosition = cursorPosition,
                    inputString = inputString, db = db)
            keyWasArrow = true
        except IOError:
          discard
        except ValueError:
          showError(message = "Invalid value for moving cursor.",
              e = getCurrentException(), db = db)
      # Ctrl-c pressed, cancel current command and return 130 result code
      of 3:
        completionMode = false
        inputString = ""
        returnCode = 130.ResultCode
        cursorPosition = 0
        commandName = "ctrl-c"
        break
      # Enter the currently selected completion into the user's input
      of 13:
        if not completionMode:
          continue
        try:
          let spaceIndex: ExtendedNatural = inputString.rfind(sub = ' ')
          inputString = inputString[0..spaceIndex] & completions[currentCompletion]
          cursorPosition = runeLen(s = $inputString)
          let line: int = (if completions.len > 3: (completions.len /
              3).int + 1 else: 1)
          stdout.cursorUp(count = (currentCompletion / 3).int)
          for i in 1..line:
            stdout.cursorDown
            stdout.eraseLine
          if line > 0:
            stdout.cursorUp(count = line)
          highlightOutput(promptLength = promptLength,
              inputString = inputString, commands = commands,
              aliases = aliases, oneTimeCommand = oneTimeCommand,
              commandName = $commandName, returnCode = returnCode, db = db,
              cursorPosition = cursorPosition, enabled = highlightEnabled)
          completionMode = false
          keyWasArrow = false
          inputChar = '\0'
        except IOError, OSError:
          discard
        except ValueError:
          showError(message = "Invalid value for character position.",
              e = getCurrentException(), db = db)
      # Any graphical character pressed, show it in the input field
      else:
        if inputChar.ord < 32:
          continue
        let inputRune: string = readChar(inputChar = inputChar, db = db)
        try:
          if promptLength + cursorPosition == terminalWidth() - 1:
            stdout.eraseLine
            discard showPrompt(promptEnabled = not oneTimeCommand,
                previousCommand = commandName, resultCode = returnCode, db = db)
            promptLength = 0
            stdout.writeLine(x = "")
          if cursorPosition > terminalWidth() and
              cursorPosition mod terminalWidth() == 0:
            stdout.writeLine(x = "")
        except IOError:
          discard
        except ValueError:
          showError(message = "Invalid value for terminal width.",
              e = getCurrentException(), db = db)
        updateInput(cursorPosition = cursorPosition,
            inputString = inputString, insertMode = insertMode,
            inputRune = inputRune)
        highlightOutput(promptLength = promptLength,
            inputString = inputString, commands = commands,
            aliases = aliases, oneTimeCommand = oneTimeCommand,
            commandName = $commandName, returnCode = returnCode, db = db,
            cursorPosition = cursorPosition, enabled = highlightEnabled)
        keyWasArrow = false
        completionMode = false
    try:
      stdout.writeLine(x = "")
    except IOError, OSError:
      discard

proc main() {.sideEffect, raises: [], tags: [ReadIOEffect, WriteIOEffect,
    ExecIOEffect, RootEffect], contractual.} =
  ## The main procedure of the shell
  body:
    startLogging()
    var
      userInput: OptParser = initOptParser()
      commandName: string = ""
      inputString: UserInput = ""
      options: OptParser = initOptParser(shortNoVal = {'h', 'v'}, longNoVal = @[
          "help", "version"])
      historyIndex: HistoryRange = -1
      oneTimeCommand, conjCommands: bool = false
      returnCode: ResultCode = QuitSuccess.ResultCode
      aliases: ref OrderedTable[AliasName, int] = newOrderedTable[AliasName,
          int]()
      dbPath: Path = (getConfigDir() & DirSep & "nish" &
          DirSep & "nish.db").Path
      cursorPosition: Natural = 0
      commands: ref Table[string, CommandData] = newTable[string, CommandData]()
      lastCommand: string = ""

    # On Unix systems, load various users' configurations for shells
    when not defined(windows):
      let profiles: array[2, string] = ["/etc/profile", getHomeDir() & ".profile"]
      for fileName in profiles:
        logToFile(message = "Loading profile: " & fileName)
        if fileExists(filename = fileName) and execCmd(command = "sh '" &
            fileName & "'") != 0:
          showError(message = "Can't load the shells configuration file '" &
              fileName & "'.", db = nil)

    # Check the command line parameters entered by the user. Available options
    # are "-c [command]" to run only one command, "-h" or "--help" to show
    # help about the shell's command line arguments, "-v" or "--version" to show
    # the shell's version info and "-db [path]" to set path to the shell's
    # database
    while true:
      options.next
      case options.kind
      of cmdEnd:
        break
      of cmdShortOption, cmdLongOption:
        case options.key
        of "c":
          oneTimeCommand = true
          options.next
          inputString = options.key
        of "h", "help":
          showCommandLineHelp()
        of "v", "version":
          showProgramVersion()
        of "db":
          dbPath = options.val.Path
      else:
        discard

    # Connect to the shell database
    let db: DbConn = startDb(dbPath = dbPath)

    # Stop shell if connection to its database was unsuccesful
    if db == nil:
      quit QuitFailure

    # Initialize the shell's database's commands
    initDb(db = db, commands = commands)

    # Initialize the shell's theme
    initTheme(db = db, commands = commands)

    # Initialize the shell's commands history
    historyIndex = initHistory(db = db, commands = commands)

    # Initialize the shell's options system
    initOptions(commands = commands, db = db)

    # Initialize the shell's aliases system
    initAliases(db = db, aliases = aliases, commands = commands)

    # Initialize the shell's environment variables system
    initVariables(db = db, commands = commands)

    # Set the shell's help
    initHelp(db = db, commands = commands)

    # Initialize the shell's commands' completion system
    initCompletion(db = db, commands = commands)

    # Initialize the shell's plugins system
    initPlugins(db = db, commands = commands)

    # Set the title of the terminal to current directory
    setTitle(title = $getFormattedDir(), db = db)

    # Start the shell
    while true:
      try:
        # Write the shell's prompt and get the input from the user, only when the
        # shell's didn't start in one command mode and there is no remaining the
        # user input to parse
        if not oneTimeCommand and inputString.len == 0:
          readUserInput(inputString = inputString,
              oneTimeCommand = oneTimeCommand, db = db,
              commandName = commandName, returnCode = returnCode,
              historyIndex = historyIndex, cursorPosition = cursorPosition,
              aliases = aliases, commands = commands)
        # User just press Enter key, reset return code (if user doesn't pressed
        # ctrl-c) and back to beginning
        if inputString.len == 0:
          if returnCode != 130:
            returnCode = QuitSuccess.ResultCode
          continue
        # User entered just the command to execute the previously entered command,
        # replace it with the previous if exists
        if inputString == "." and lastCommand.len > 0:
          inputString = lastCommand
        userInput = initOptParser(cmdLine = $inputString)
        # Reset the return code of the program
        returnCode = QuitSuccess.ResultCode
        # Go to the first token
        userInput.next
        # If it looks like an argument, it must be command name
        if userInput.kind == cmdArgument:
          commandName = userInput.key
        # Set the command arguments
        var arguments: UserInput =
          getArguments(
              userInput = userInput, conjCommands = conjCommands)
        inputString = join(a = userInput.remainingArgs, sep = " ")
        # Set a terminal title to current command
        setTitle(title = commandName & " " & $arguments, db = db)
        # Execute plugins with precommand hook
        try:
          var plugins: seq[Plugin] = @[newPlugin()]
          db.select(objs = plugins, cond = "precommand=1 AND enabled=1")
          for plugin in plugins:
            discard execPlugin(pluginPath = plugin.location, arguments = [
                "preCommand", commandName & " " & arguments], db = db,
                    commands = commands)
        except DbError:
          showError(message = "Can't execute preCommand hook for plugins. Reason: ",
              e = getCurrentException(), db = db)
        let withShell: bool = getOption(optionName = "execWithShell", db = db,
            defaultValue = "true") == "true"
        # Parse commands
        case commandName
        # Quit from shell
        of "exit":
          historyIndex = updateHistory(commandToAdd = "exit", db = db)
          try:
            setTitle(title = $getCurrentDirectory(), db = db)
          except OSError:
            setTitle(title = "nish", db = db)
          closeDb(returnCode = returnCode, db = db)
        # Change current directory
        of "cd":
          returnCode = cdCommand(newDirectory = ($arguments).Path,
              aliases = aliases, db = db)
        # Set the environment variable
        of "set":
          returnCode = setCommand(arguments = arguments, db = db)
        # Delete environment variable
        of "unset":
          returnCode = unsetCommand(arguments = arguments, db = db)
        # Execute the command without using the system's default shell
        of "exec":
          if arguments.len == 0:
            returnCode = showError(message = "Enter a command to execute.", db = db)
          else:
            let spaceIndex: int = arguments.find(sub = ' ')
            if spaceIndex > 0:
              commandName = $(arguments[0 .. spaceIndex - 1])
              arguments = (
                  arguments[spaceIndex + 1 .. ^1])
            else:
              commandName = $arguments
              arguments = ""
            returnCode = executeCommand(commands = commands,
                commandName = commandName, arguments = arguments,
                inputString = inputString, db = db, aliases = aliases,
                cursorPosition = cursorPosition, withShell = not withShell)
        # Execute command (the shell's or external) or the shell's alias
        else:
          returnCode = executeCommand(commands = commands,
              commandName = commandName, arguments = arguments,
              inputString = inputString, db = db, aliases = aliases,
              cursorPosition = cursorPosition, withShell = withShell)
        # If the command returned 0 (unknown command), suggest other command
        logToFile(message = "returnCode = " & $returnCode)
        if returnCode == 127:
          fillSuggestionsList(aliases = aliases, commands = commands)
          var
            start: Natural = 0
            inputChanged: bool = false
          while true:
            let
              oldStart: Natural = start
              newCommand: string = suggestCommand(invalidName = $commandName,
                start = start, db = db)
            if newCommand.len == 0:
              break
            showOutput(message = "Command '" & style(ss = commandName,
                style = getColor(db = db, name = suggestInvalid)) &
                "' not found. Did you mean: '" & style(ss = newCommand,
                style = getColor(db = db, name = suggestCommand)) & "'? [" &
                style(ss = "Y", style = getColor(db = db, name = suggestYes)) &
                "]es/[" & style(ss = "N", style = getColor(db = db,
                name = suggestNext)) & "]ext/[" & style(ss = "A",
                style = getColor(db = db, name = suggestAbort)) & "]bort", db = db)
            case getch()
            of 'Y', 'y':
              inputString = newCommand & " " & arguments
              inputChanged = true
              break
            of 'A', 'a':
              break
            of 'N', 'n':
              continue
            else:
              start = oldStart
          if inputChanged:
            continue
        # Update the shell's history with info about the executed command
        lastCommand = commandName & (if arguments.len > 0: " " &
            arguments else: "")
        historyIndex = updateHistory(commandToAdd = lastCommand, db = db,
            returnCode = returnCode)
        # Restore the terminal title
        setTitle(title = $getFormattedDir(), db = db)
        # Execute plugins with postcommand hook
        try:
          var plugins: seq[Plugin] = @[newPlugin()]
          db.select(objs = plugins, cond = "postcommand=1 AND enabled=1")
          for plugin in plugins:
            discard execPlugin(pluginPath = plugin.location, arguments = [
                "postCommand", commandName & " " & arguments], db = db,
                    commands = commands)
        except DbError:
          showError(message = "Can't execute postCommand hook for plugins. Reason: ",
              e = getCurrentException(), db = db)
        # If there is more commands to execute check if the next commands should
        # be executed. if the last command wasn't success and commands conjuncted
        # with && or the last command was success and command disjuncted, reset
        # the input, don't execute more commands.
        if inputString.len > 0 and ((returnCode != QuitSuccess and
            conjCommands) or (returnCode == QuitSuccess and not conjCommands)):
          inputString = ""
        # Run only one command, quit from the shell
        if oneTimeCommand and inputString.len == 0:
          closeDb(returnCode = returnCode, db = db)
        cursorPosition = runeLen(s = $inputString)
      except:
        showError(message = "Internal shell error. Additional details: ",
            e = getCurrentException(), db = db)

when isMainModule:
  main()
