# Copyright © 2022 Bartek Jasicki <thindil@laeran.pl>
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

import std/[parseopt, strutils, terminal]
import constants, lstring, output

const maxInputLength*: Positive = 4096 # The maximum length of the user input

proc readInput*(maxLength: Positive = maxInputLength): UserInput {.gcsafe,
    sideEffect, raises: [], tags: [WriteIOEffect, ReadIOEffect, TimeEffect].} =
  ## FUNCTION
  ##
  ## Read the user input. Used in adding a new or editing an existing alias
  ## or environment variable
  ##
  ## PARAMETERS
  ##
  ## * maxLength - the maximum length of the user input to parse. Default value
  ##               is the constant maxInputLength
  ##
  ## RETURNS
  ##
  ## The user input text or "exit" if there was an error or the user pressed
  ## Escape key
  # Get the user input and parse it
  let exitString: LimitedString =
    try:
      initLimitedString(capacity = 4, text = "exit")
    except CapacityError:
      return
  var inputChar: char = '\0'
  # Read the user input until not meet new line character or the input
  # reach the maximum length
  while inputChar.ord() != 13 and result.len() < maxLength:
    # Backspace pressed, delete the last character from the user input
    if inputChar.ord() == 127:
      if result.len() > 0:
        result = result[0..^2]
        try:
          stdout.cursorBackward()
          stdout.write(s = " ")
          stdout.cursorBackward()
        except IOError, ValueError:
          discard showError(message = "Can't delete character. Reason: " &
              getCurrentExceptionMsg())
          return exitString
    # Special key pressed (all starts like Escape key), check which one
    elif inputChar.ord() == 27:
      try:
        inputChar = getch()
      except IOError as e:
        discard showError(message = "Can't get the next character after Escape. Reason: " & e.msg)
        return exitString
      # Escape key pressed, return "exit" as input value
      if inputChar.ord() == 27:
        return exitString
      else:
        continue
    # Visible character, add it to the user input string and show it in the
    # console
    elif inputChar.ord() > 31:
      stdout.write(c = inputChar)
      try:
        result.add(y = inputChar)
      except CapacityError:
        return result
    try:
      inputChar = getch()
    except IOError as e:
      discard showError(message = "Can't get the next character. Reason: " & e.msg)
      return exitString
  try:
    stdout.writeLine(x = "")
  except IOError as e:
    discard showError(message = "Can't add a new line. Reason: " & e.msg)
    return exitString

func getArguments*(userInput: var OptParser;
    conjCommands: var bool): UserInput {.gcsafe, raises: [], tags: [].} =
  ## FUNCTION
  ##
  ## Set the command arguments from the user input
  ##
  ## PARAMETERS
  ##
  ## * userInput    - the input string entered by the user
  ## * conjCommands - if true, set the commands to run next only if the previous
  ##                  was successful, otherwise run the next command only when
  ##                  previous was failure
  ##
  ## RETURNS
  ##
  ## Properly converted user input and parameter conjCommands
  result = emptyLimitedString(capacity = maxInputLength)
  userInput.next()
  conjCommands = false
  var key: string
  while userInput.kind != cmdEnd:
    if userInput.key == "&&":
      conjCommands = true
      break
    if userInput.key == "||":
      break
    if userInput.key.contains(sub = " "):
      key = "\"" & userInput.key & "\""
    else:
      key = userInput.key
    try:
      case userInput.kind
      of cmdLongOption:
        if userInput.val.len() > 0:
          result.add(y = "--" & key & "=")
          if userInput.val.contains(sub = " "):
            result.add(y = "\"" & userInput.val & "\"")
          else:
            result.add(userInput.val)
        else:
          result.add(y = "--" & key)
      of cmdShortOption:
        result.add(y = "-" & key)
      of cmdArgument:
        result.add(y = key)
      of cmdEnd:
        discard
      result.add(y = " ")
      userInput.next()
    except CapacityError:
      break
  try:
    result.setString(text = strip(s = $result))
  except CapacityError:
    return
