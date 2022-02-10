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
import aliases, commands, constants, help, history, options, output

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

  # Initialize the shell's commands history
  historyIndex = initHistory(db, helpContent)

  # Initialize the shell's options system
  initOptions(helpContent)

  # Initialize the shell's aliases system
  aliases = initAliases(helpContent, db)

  # Set the main content for help if user enters only help command
  updateHelp(helpContent, db)
  helpContent["main"] = """
  Available commands are: cd, exit, help, set, unset, alias, alias list, alias
  delete, alias show, alias add, alias edit, history, history clear, options, options show, options
  set, options reset

  To see more information about the command, type help [command], for
  example: help cd.
  """

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
      # Parse commands
      case commandName
      # Quit from shell
      of "exit":
        historyIndex = updateHistory("exit", db)
        quitShell(returnCode, db)
      # Show help screen
      of "help":
        userInput.next()
        # If user entered only "help", show the main help screen
        if userInput.kind == cmdEnd:
          showOutput(helpContent["main"])
          historyIndex = updateHistory("help", db)
        elif userInput.key == "cd":
          showOutput("""
        Usage: cd [directory]

        You must have permissions to enter the directory and directory
        need to exists. If you enter just 'cd' without the name of the
        directory to enter, the current directory will be switched to
        your home directory.
        """)
          historyIndex = updateHistory("help cd", db)
        elif userInput.key == "exit":
          showOutput("""
        Usage: exit

        Exit from the shell.
        """)
          historyIndex = updateHistory("help exit", db)
        elif userInput.key == "help":
          showOutput("""
        Usage help ?command?

        If entered only as help, show the list of available commands,
        when also command entered, show the information about the selected
        command.
        """)
          historyIndex = updateHistory("help help", db)
        elif userInput.key == "set":
          showOutput("""
        Usage set [name=value]

        Set the environment variable with the selected name and value.
          """)
          historyIndex = updateHistory("help set", db)
        elif userInput.key == "unset":
          showOutput("""
        Usage unset [name]

        Remove the environment variable with the selected name.
          """)
          historyIndex = updateHistory("help unset", db)
        elif userInput.key == "alias":
          userInput.next()
          # If user entered only "alias", show the help for it
          if userInput.kind == cmdEnd:
            showOutput(helpContent["alias"])
            historyIndex = updateHistory("help alias", db)
          elif userInput.key == "list":
            showOutput(helpContent["alias list"])
            historyIndex = updateHistory("help alias list", db)
          elif userInput.key == "delete":
            showOutput(helpContent["alias delete"])
            historyIndex = updateHistory("help alias delete", db)
          elif userInput.key == "show":
            showOutput(helpContent["alias show"])
            historyIndex = updateHistory("help alias show", db)
          elif userInput.key == "add":
            showOutput(helpContent["alias add"])
            historyIndex = updateHistory("help alias add", db)
          elif userInput.key == "edit":
            showOutput(helpContent["alias edit"])
            historyIndex = updateHistory("help alias edit", db)
          else:
            returnCode = showUnknownHelp(userInput.key, "alias", "aliases")
            historyIndex = updateHistory("help alias " & userInput.key, db, returnCode)
        elif userInput.key == "history":
          userInput.next()
          # If user entered only "history", show the help for it
          if userInput.kind == cmdEnd:
            showOutput(helpContent["history"])
            historyIndex = updateHistory("help history", db)
          elif userInput.key == "clear":
            showOutput(helpContent["history clear"])
            historyIndex = updateHistory("help history clear", db)
          elif userInput.key == "show":
            showOutput(helpContent["history show"])
            historyIndex = updateHistory("help history show", db)
          else:
            returnCode = showUnknownHelp(userInput.key, "history", "history")
            historyIndex = updateHistory("help history " & userInput.key, db, returnCode)
        elif userInput.key == "options":
          userInput.next()
          # If user entered only "options", show the help for it
          if userInput.kind == cmdEnd:
            showOutput(helpContent["options"])
            historyIndex = updateHistory("help options", db)
          elif userInput.key == "show":
            showOutput(helpContent["options show"])
            historyIndex = updateHistory("help options show", db)
          elif userInput.key == "set":
            showOutput(helpContent["options set"])
            historyIndex = updateHistory("help options set", db)
          elif userInput.key == "reset":
            showOutput(helpContent["options reset"])
            historyIndex = updateHistory("help options reset", db)
          else:
            returnCode = showUnknownHelp(userInput.key, "options", "options")
            historyIndex = updateHistory("help options " & userInput.key, db, returnCode)
        else:
          returnCode = showError("Uknown command '" & userInput.key & "'")
          historyIndex = updateHistory("help " & userInput.key, db, returnCode)
      # Change current directory
      of "cd":
        returnCode = cdCommand(userInput, aliases, db)
        historyIndex = historyLength(db)
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
            except OSError:
              returnCode = showError()
            historyIndex = updateHistory("set " & userInput.key, db, returnCode)
      # Delete environment variable
      of "unset":
        userInput.next()
        if userInput.kind != cmdEnd:
          try:
            delEnv(userInput.key)
            showOutput("Environment variable '" & userInput.key & "' removed",
                true, not oneTimeCommand, commandName, returnCode)
          except OSError:
            returnCode = showError()
          historyIndex = updateHistory("unset " & userInput.key, db, returnCode)
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
