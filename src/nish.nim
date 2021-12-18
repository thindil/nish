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

import std/[os, osproc, parseopt, strutils]

var
  userInput: OptParser
  commandName: string = ""
  oneTimeCommand: bool = false
  options: OptParser = initOptParser(commandLineParams())
  returnCode: int = QuitSuccess

# Check if run only one command, by command line argument "-c [command]"
for kind, key, value in options.getopt():
  if kind == cmdShortOption and key == "c":
    oneTimeCommand = true
  if oneTimeCommand and kind == cmdArgument:
    # Set the command to execute in shell
    userInput = initOptParser(key)
    break

proc getPrompt(): string =
  ## Get the command shell prompt
  if not oneTimeCommand:
    result = getCurrentDir()
    if commandName != "" and returnCode != QuitSuccess:
      result.add(" [Error: " & $returnCode & "] ")
    result.add("# ");

# Start the shell
while true:
  try:
    # Run only one command, don't show prompt and wait for the user input
    if not oneTimeCommand:
      # Write prompt
      write(stdout, getPrompt())
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
        echo getPrompt() & """Available commands are: cd, exit, help, set, unset

      To see more information about the command, type help [command], for
      example: help cd.
      """
      elif userInput.key == "cd":
        echo getPrompt() & """Usage: cd [directory]

      You must have permissions to enter the directory and directory
      need to exists.
      """
      elif userInput.key == "exit":
        echo getPrompt() & """Usage: exit

      Exit from the shell.
      """
      elif userInput.key == "help":
        echo getPrompt() & """Usage help ?command?

      If entered only as help, show the list of available commands,
      when also command entered, show the information about the selected
      command.
      """
      elif userInput.key == "set":
        echo getPrompt() & """Usage set [name=value]

      Set the environment variable with the selected name and value.
        """
      elif userInput.key == "unset":
        echo getPrompt() & """Usage unset [name]

      Remove the environment variable with the selected name.
        """
      else:
        echo getPrompt() & "Uknown command '" & userInput.key & "'"
        returnCode = QuitFailure
    # Change current directory
    of "cd":
      userInput.next()
      if userInput.kind != cmdEnd:
        var path: string = userInput.key
        if path[0] == '~':
          path = expandTilde(path)
        else:
          path = absolutePath(path)
          try:
            setCurrentDir(path)
          except OSError:
            echo getPrompt() & getCurrentExceptionMsg()
            returnCode = QuitFailure
    # Set the environment variable
    of "set":
      userInput.next()
      if userInput.kind != cmdEnd:
        let varValues = userInput.key.split("=")
        if varValues.len > 1:
          try:
            putEnv(varValues[0], varValues[1])
            echo getPrompt() & "Environment variable '" & varValues[0] &
                "' set to '" & varValues[1] & "'"
          except OSError:
            echo getPrompt() & getCurrentExceptionMsg()
            returnCode = QuitFailure
    # Delete environment variable
    of "unset":
      userInput.next()
      if userInput.kind != cmdEnd:
        try:
          delEnv(userInput.key)
          echo getPrompt() & "Environment variable '" & userInput.key &
              "' removed"
        except OSError:
          echo getPrompt() & getCurrentExceptionMsg()
          returnCode = QuitFailure
    # Execute external command
    else:
      returnCode = execCmd(commandName & " " &
        join(userInput.remainingArgs, " "))
  except:
    echo getPrompt() & getCurrentExceptionMsg()
    returnCode = QuitFailure
  finally:
    # Run only one command, quit from the shell
    if oneTimeCommand:
      quit returnCode
