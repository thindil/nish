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

proc getPrompt(): string =
  ## Get the command shell prompt
  getCurrentDir() & "# "

# Start the shell
while true:
  # Reset name of the command to execute
  commandName = ""
  # Write prompt
  write(stdout, getPrompt())
  # Get the user input and parse it
  userInput = initOptParser(readLine(stdin))
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
    echo getPrompt() & "Available commands are: cd, exit, help"
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
        echo getPrompt() & "Directory '" & path & "' doesn't exist."
  # Execute external command
  else:
    discard execCmd(commandName & " " & join(userInput.remainingArgs, " "))
