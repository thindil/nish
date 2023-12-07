# Copyright © 2022-2023 Bartek Jasicki
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

## The module contains code related to coloring the user's input in the shell.

# Standard library imports
import std/[os, strutils, tables, terminal, unicode]
# External modules imports
import contracts
import norm/sqlite
# Internal imports
import commandslist, constants, lstring, output, prompt, resultcode, theme

proc highlightOutput*(promptLength: Natural; inputString: var UserInput;
    commands: ref Table[string, CommandData]; aliases: ref AliasesList;
    oneTimeCommand: bool; commandName: string; returnCode: ResultCode;
    db: DbConn; cursorPosition: Natural; enabled: bool) {.sideEffect, raises: [],
    tags: [WriteIOEffect, ReadIOEffect, ReadDbEffect, TimeEffect, RootEffect],
    contractual.} =
  ## Refresh the user input, clear the old and show the new. Color the entered
  ## command on green if it is valid or red if invalid
  ##
  ## * promptLength   - the length of the last line of the shell's prompt. If
  ##                    equal to 0, don't refresh it
  ## * inputString    - the command with arguments entered by the user
  ## * commands       - the list of the shell's commands
  ## * aliases        - the list of available shell's aliases
  ## * oneTimeCommand - if true, the shell runs only one command and exit
  ## * commandName    - the name of the previously entered command
  ## * returnCode     - the code returned by the previously entered command
  ## * db             - the connection to the shell's database
  ## * cursorPosition - the position of the cursor on the screen
  ## * enabled        - if true, the syntax highlightning is enabled, otherwise
  ##                    false
  require:
    commands != nil
    aliases != nil
    db != nil
  body:
    try:
      stdout.eraseLine
      let
        input: UserInput = try:
            initLimitedString(capacity = maxInputLength, text = strutils.strip(
                s = $inputString, trailing = false))
          except CapacityError:
            emptyLimitedString(capacity = maxInputLength)
      var
        spaceIndex: ExtendedNatural = input.find(sub = ' ')
        command: UserInput = try:
            initLimitedString(capacity = maxInputLength, text = (if spaceIndex <
                1: $input else: $input[0..spaceIndex - 1]))
          except CapacityError:
            emptyLimitedString(capacity = maxInputLength)
      # Show the prompt if enabled
      if promptLength > 0 and promptLength + runeLen(s = $input) <=
          terminalWidth():
        showPrompt(promptEnabled = not oneTimeCommand,
            previousCommand = $commandName, resultCode = returnCode, db = db)
      # Erase the previous content if the new line is longer than the terminal's
      # width
      if promptLength + runeLen(s = $input) > terminalWidth():
        let linesToDelete: int = (runeLen(s = $input) / terminalWidth()).int
        for i in 1 .. linesToDelete:
          stdout.cursorUp
          stdout.eraseLine
        if runeLen(s = $input) mod terminalWidth() == 0:
          stdout.cursorDown
      # If syntax highlightning is disabled, show the user's input and quit
      if not enabled:
        inputString = input
        showOutput(message = $inputString, newLine = false, db = db)
        return
      # If command contains equal sign it must be an environment variable,
      # print the variable and get the next word
      while '=' in $command:
        showOutput(message = $command, newLine = false, color = highlightVariable, db = db)
        var startIndex: int = input.find(sub = ' ', start = (if spaceIndex >
            -1: spaceIndex else: 0))
        if startIndex < 0:
          inputString = input
          return
        showOutput(message = " ", newLine = false, db = db)
        startIndex.inc
        spaceIndex = input.find(sub = ' ', start = startIndex)
        command = try:
            initLimitedString(capacity = maxInputLength, text = (if spaceIndex <
                1: $input[startIndex..^1] else: $input[startIndex..spaceIndex - 1]))
          except CapacityError:
            emptyLimitedString(capacity = maxInputLength)
        if spaceIndex == -1:
          spaceIndex = input.len
      let commandArguments: UserInput = try:
            initLimitedString(capacity = maxInputLength, text = (if spaceIndex <
                1: "" else: $input[spaceIndex..^1]))
          except CapacityError:
            emptyLimitedString(capacity = maxInputLength)
      var color: ThemeColor = try:
          if findExe(exe = $command).len > 0:
            highlightValid
          else:
            highlightInvalid
        except OSError:
          highlightValid
      if color == highlightInvalid:
        # Built-in commands
        if $command in ["exit", "cd", "set", "unset", "."]:
          color = highlightValid
        # The shell's commands
        elif commands.hasKey(key = $command):
          color = highlightValid
        # Aliases
        elif aliases.contains(key = command):
          color = highlightValid
      showOutput(message = $command, newLine = false, color = color, db = db)
      # Check if command's arguments contains quotes
      var
        quotes: set[char] = {'\'', '"'}
        quotePosition: int = find(s = $commandArguments, chars = quotes)
        startPosition: int = 0
      # No quotes, print all
      if quotePosition == -1:
        showOutput(message = $commandArguments, newLine = false, db = db)
      # Color the text inside the quotes
      else:
        color = default
        while quotePosition > -1:
          showOutput(message = $commandArguments[startPosition..quotePosition -
              1], newLine = false, color = color, db = db)
          showOutput(message = $commandArguments[quotePosition],
              newLine = false, color = highlightText, db = db)
          startPosition = quotePosition + 1
          if color == default:
            color = highlightText
            quotes = {commandArguments[quotePosition]}
          else:
            color = default
            quotes = {'\'', '"'}
          quotePosition = find(s = $commandArguments, chars = quotes,
              start = startPosition)
        showOutput(message = $commandArguments[startPosition..^1],
            newLine = false, color = color, db = db)
      if cursorPosition < runeLen(s = $input) - 1:
        stdout.cursorBackward(count = runeLen(s = $input) - cursorPosition)
      inputString = input
    except:
      showError(message = "Can't highlight input. Reason: ",
          e = getCurrentException(), db = db)
