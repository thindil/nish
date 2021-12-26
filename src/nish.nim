# Copyright © 2021 Bartek Jasicki
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

import std/[os, osproc, parseopt, strutils, terminal]

const
  maxInputLength = 4096
  maxHistoryLength = 500

var
  userInput: OptParser
  commandName: string = ""
  oneTimeCommand: bool = false
  options: OptParser = initOptParser(shortNoVal = {'h'}, longNoVal = @["help"])
  returnCode: int = QuitSuccess
  history: seq[string]
  historyIndex: int = 0
  inputString: string = ""

proc showCommandLineHelp() =
  ## Show the program arguments help
  echo """Available arguments are:
    -c [command] - Run the selected command in shell and quit
    -h, --help   - Show this help and quit"""
  quit QuitSuccess

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
  of cmdLongOption:
    if key == "help":
      showCommandLineHelp()
  of cmdArgument:
    if oneTimeCommand:
      # Set the command to execute in shell
      userInput = initOptParser(key)
      break
  else: discard

proc showPrompt() =
  ## Show the shell prompt if the shell wasn't started in one command mode
  if oneTimeCommand:
    return
  if getCurrentDir() & "/" == getHomeDir():
    styledWrite(stdout, fgBlue, "~")
  else:
    styledWrite(stdout, fgBlue, replace(getCurrentDir(), getHomeDir(), "~/"))
  if commandName != "" and returnCode != QuitSuccess:
    styledWrite(stdout, fgRed, "[" & $returnCode & "]")
  styledWrite(stdout, fgBlue, "# ")

proc showOutput(message: string; newLine: bool = true) =
  ## Show the selected message and prompt to the user. If newLine is true
  ## (default), add a new line after message
  showPrompt()
  if message != "":
    write(stdout, message)
    if newLine:
      writeLine(stdout, "")
  flushFile(stdout)

proc showError() =
  ## Print the exception message to standard error and set the shell return
  ## code to error
  styledWriteLine(stderr, fgRed, getCurrentExceptionMsg())
  returnCode = QuitFailure

proc updateHistory(commandToAdd: string) =
  ## Add the selected command to the shell history and increase the current
  ## history index
  if history.len() == maxHistoryLength:
    history.delete(1)
  history.add(commandToAdd)
  historyIndex = history.len() - 1

proc noControlC() {.noconv.} =
  ## Block quitting from the shell with Control-C key, show info how to
  ## quit from the program
  cursorBackward(stdout, 2)
  echo "If you want to exit the shell, type 'exit' and press Enter"
  showPrompt()

setControlCHook(noControlC)

# Start the shell
while true:
  try:
    # Run only one command, don't show prompt and wait for the user input
    if not oneTimeCommand:
      # Write prompt
      showPrompt()
      # Get the user input and parse it
      var inputChar: char
      # Reset previous input
      inputString = ""
      inputChar = '\0'
      # Read the user input until not meet new line character or the input
      # reach the maximum length
      while ord(inputChar) != 13 and inputString.len() < maxInputLength:
        # Backspace pressed, delete the last character from the user input
        if ord(inputChar) == 127:
          if inputString.len() > 0:
            inputString = inputString[0..^2]
            cursorBackward(stdout)
            write(stdout, " ")
            cursorBackward(stdout)
        # Escape or arrows keys pressed
        elif ord(inputChar) == 27:
          # Arrow key pressed
          if getch() == '[':
            # Arrow up key pressed
            inputChar = getch()
            if inputChar == 'A' and history.len() > 0:
              eraseLine(stdout)
              showOutput(history[historyIndex], false)
              inputString = history[historyIndex]
              dec(historyIndex)
              if historyIndex < 0:
                historyIndex = 0;
            # Arrow down key pressed
            elif inputChar == 'B' and history.len() > 0:
              inc(historyIndex)
              if historyIndex >= history.len():
                historyIndex = history.len() - 1
              eraseLine(stdout)
              showOutput(history[historyIndex], false)
              inputString = history[historyIndex]
        elif ord(inputChar) > 31:
          write(stdout, inputChar)
          inputString.add(inputChar)
        inputChar = getch()
      writeLine(stdout, "")
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
      quit returnCode
    # Show help screen
    of "help":
      userInput.next()
      # If user entered only "help", show the main help screen
      if userInput.kind == cmdEnd:
        showOutput("""Available commands are: cd, exit, help, set, unset

      To see more information about the command, type help [command], for
      example: help cd.
      """)
        updateHistory("help")
      elif userInput.key == "cd":
        showOutput("""Usage: cd [directory]

      You must have permissions to enter the directory and directory
      need to exists.
      """)
        updateHistory("help cd")
      elif userInput.key == "exit":
        showOutput("""Usage: exit

      Exit from the shell.
      """)
        updateHistory("help exit")
      elif userInput.key == "help":
        showOutput("""Usage help ?command?

      If entered only as help, show the list of available commands,
      when also command entered, show the information about the selected
      command.
      """)
        updateHistory("help help")
      elif userInput.key == "set":
        showOutput("""Usage set [name=value]

      Set the environment variable with the selected name and value.
        """)
        updateHistory("help set")
      elif userInput.key == "unset":
        showOutput("""Usage unset [name]

      Remove the environment variable with the selected name.
        """)
        updateHistory("help unset")
      else:
        showOutput("Uknown command '" & userInput.key & "'")
        returnCode = QuitFailure
    # Change current directory
    of "cd":
      userInput.next()
      if userInput.kind != cmdEnd:
        let path: string = absolutePath(expandTilde(userInput.key))
        try:
          setCurrentDir(path)
          updateHistory("cd " & userInput.key)
        except OSError:
          showError()
    # Set the environment variable
    of "set":
      userInput.next()
      if userInput.kind != cmdEnd:
        let varValues = userInput.key.split("=")
        if varValues.len > 1:
          try:
            putEnv(varValues[0], varValues[1])
            showOutput("Environment variable '" & varValues[0] &
                "' set to '" & varValues[1] & "'")
            updateHistory("set " & userInput.key)
          except OSError:
            styledWriteLine(stderr, fgRed, getCurrentExceptionMsg())
            returnCode = QuitFailure
    # Delete environment variable
    of "unset":
      userInput.next()
      if userInput.kind != cmdEnd:
        try:
          delEnv(userInput.key)
          showOutput("Environment variable '" & userInput.key & "' removed")
          updateHistory("unset " & userInput.key)
        except OSError:
          showError()
    # Execute external command
    else:
      let commandToExecute = commandName & " " &
        join(userInput.remainingArgs, " ")
      returnCode = execCmd(commandToExecute)
      if returnCode == QuitSuccess:
        updateHistory(commandToExecute)
  except:
    showError()
  finally:
    # Run only one command, quit from the shell
    if oneTimeCommand:
      quit returnCode
