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

var
  userInput: OptParser
  commandName: string = ""
  oneTimeCommand: bool = false
  options: OptParser = initOptParser(shortNoVal = {'h'}, longNoVal = @["help"])
  returnCode: int = QuitSuccess

proc showCommandLineHelp() =
  ## Show the program arguments help
  echo """Available arguments are:
    -c [command] - Run the selected command in shell and quit
    -h, --help   - Show this help and quit"""
  quit returnCode

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

proc showOutput(message: string) =
  ## Show the selected message and prompt to the user
  if not oneTimeCommand:
    if getCurrentDir() & "/" == getHomeDir():
      styledWrite(stdout, fgBlue, "~")
    else:
      styledWrite(stdout, fgBlue, replace(getCurrentDir(), getHomeDir(), "~/"))
    if commandName != "" and returnCode != QuitSuccess:
      styledWrite(stdout, fgRed, "[" & $returnCode & "]")
    styledWrite(stdout, fgBlue, "# ")
  write(stdout, message)

proc showError() =
  ## Print the exception message to standard error and set the shell return
  ## code to error
  styledWriteLine(stderr, fgRed, getCurrentExceptionMsg())
  returnCode = QuitFailure

proc noControlC() {.noconv.} =
  ## Block quitting from the shell with Control-C key, show info how to
  ## quit from the program
  echo "If you want to exit the shell, type 'exit' and press Enter"
  showOutput("")

setControlCHook(noControlC)

# Start the shell
while true:
  try:
    # Run only one command, don't show prompt and wait for the user input
    if not oneTimeCommand:
      # Write prompt
      showOutput("")
      # Get the user input and parse it
      userInput = initOptParser(readLine(stdin))
      # Reset name of the command to execute
      commandName = ""
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
      break
    # Show help screen
    of "help":
      userInput.next()
      # If user entered only "help", show the main help screen
      if userInput.kind == cmdEnd:
        showOutput("""Available commands are: cd, exit, help, set, unset

      To see more information about the command, type help [command], for
      example: help cd.
      """)
      elif userInput.key == "cd":
        showOutput("""Usage: cd [directory]

      You must have permissions to enter the directory and directory
      need to exists.
      """)
      elif userInput.key == "exit":
        showOutput("""Usage: exit

      Exit from the shell.
      """)
      elif userInput.key == "help":
        showOutput("""Usage help ?command?

      If entered only as help, show the list of available commands,
      when also command entered, show the information about the selected
      command.
      """)
      elif userInput.key == "set":
        showOutput("""Usage set [name=value]

      Set the environment variable with the selected name and value.
        """)
      elif userInput.key == "unset":
        showOutput("""Usage unset [name]

      Remove the environment variable with the selected name.
        """)
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
        except OSError:
          showError()
    # Execute external command
    else:
      returnCode = execCmd(commandName & " " &
        join(userInput.remainingArgs, " "))
  except:
    showError()
  finally:
    # Run only one command, quit from the shell
    if oneTimeCommand:
      quit returnCode
