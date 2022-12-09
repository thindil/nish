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

# Standard library imports
import std/[parseopt, strutils, terminal, unicode]
# External modules imports
import contracts
# Internal imports
import constants, lstring, output

const maxInputLength*: Positive = 4096
  ## FUNCTION
  ##
  ## The maximum length of the user input

type MaxInputLength* = range[1..maxInputLength]
  ## FUNCTION
  ##
  ## Used to store maximum allowed length of the user input

proc readChar*(inputChar: char): string {.gcsafe, sideEffect, raises: [],
    tags: [WriteIOEffect, ReadIOEffect], contractual.} =
  ## FUNCTION
  ##
  ## Read the Unicode character from the user's input
  ##
  ## PARAMETERS
  ##
  ## * inputChar - the last printable character entered by the user
  ##
  ## RETURNS
  ##
  ## The string with full Unicode character entered by the user
  require:
    inputChar.ord > 31
  ensure:
    result.len > 0
  body:
    result = $inputChar
    try:
      if inputChar.ord > 192:
        result.add(y = getch())
      if inputChar.ord > 223:
        result.add(y = getch())
      if inputChar.ord > 239:
        result.add(y = getch())
    except IOError:
      showError(message = "Can't get the entered Unicode character. Reason: ",
          e = getCurrentException())

proc deleteChar*(inputString: var UserInput;
    cursorPosition: var Natural) {.gcsafe, sideEffect, raises: [], tags: [
    WriteIOEffect], contractual.} =
  ## FUNCTION
  ##
  ## Delete the Unicode character at the selected position from the user's input
  ##
  ## PARAMETERS
  ##
  ## * inputString    - the string of characters entered by the user
  ## * cursorPosition - the position of the cursor in the string
  ##
  ## RETURNS
  ##
  ## Modified inputString and the new cursor position as cursorPosition
  body:
    var runes = toRunes(s = $inputString)
    cursorPosition.dec
    runes.delete(i = cursorPosition)
    try:
      inputString.text = $runes
    except CapacityError:
      showError(message = "Entered input is too long.", e = getCurrentException())

proc moveCursor*(inputChar: char; cursorPosition: var Natural;
    inputString: UserInput) {.gcsafe, sideEffect, raises: [], tags: [
    WriteIOEffect], contractual.} =
  ## FUNCTION
  ##
  ## Move the cursor inside the user's input
  ##
  ## PARAMETERS
  ##
  ## * inputChar      - the last ASCII character entered by the user
  ## * cursorPosition - the current position of cursor in the user's input
  ## * inputString    - the user's input's content
  ##
  ## RETURNS
  ##
  ## The new position of the cursor as modified cursorPosition argument
  body:
    try:
      # Arrow left key pressed
      if inputChar == 'D' and cursorPosition > 0:
        stdout.cursorBackward
        cursorPosition.dec
      # Arrow right key pressed
      elif inputChar == 'C' and cursorPosition < runeLen(s = $inputString):
        stdout.cursorForward
        cursorPosition.inc
      # Home key pressed
      elif inputChar == 'H' and cursorPosition > 0:
        stdout.cursorBackward(count = cursorPosition)
        cursorPosition = 0
      # End key pressed
      elif inputChar == 'F' and cursorPosition < runeLen(s = $inputString):
        stdout.cursorForward(count = runeLen(s = $inputString) - cursorPosition)
        cursorPosition = runeLen(s = $inputString)
    except IOError, ValueError:
      showError(message = "Can't move the cursor. Reason: ",
          e = getCurrentException())

proc updateInput*(cursorPosition: var Natural; inputString: var UserInput;
    insertMode: bool; inputRune: string) {.gcsafe, sideEffect, raises: [],
    tags: [WriteIOEffect], contractual.} =
  ## FUNCTION
  ##
  ## Update the user's input with the new Unicode character
  ##
  ## PARAMETERS
  ##
  ## * cursorPosition - the current position of cursor in the user's input
  ## * inputString    - the user's input's content
  ## * insertMode     - if true, the input is in the insert (replace) mode
  ## * inputRune      - the Unicode character to enter to the user's input
  ##
  ## RETURNS
  ##
  ## The new cursor position as modified cursorPosition and the modified user's
  ## input's content as inputString
  if cursorPosition < runeLen(s = $inputString):
    if insertMode:
      var runes = toRunes(s = $inputString)
      runes[cursorPosition] = inputRune.toRunes[0]
      try:
        inputString.text = $runes
      except CapacityError:
        showError(message = "Entered input is too long.",
            e = getCurrentException())
    else:
      var runes = toRunes(s = $inputString)
      runes.insert(item = inputRune.toRunes[0], i = cursorPosition)
      try:
        inputString.text = $runes
        cursorPosition.inc
      except CapacityError:
        showError(message = "Entered input is too long.",
            e = getCurrentException())
  else:
    try:
      inputString.add(y = inputRune)
      cursorPosition.inc
    except CapacityError:
      showError(message = "Entered input is too long.", e = getCurrentException())

proc readInput*(maxLength: MaxInputLength = maxInputLength): UserInput {.gcsafe,
    sideEffect, raises: [], tags: [WriteIOEffect, ReadIOEffect, TimeEffect],
    contractual.} =
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
  ensure:
    result.capacity == maxLength
  body:
    # Get the user input and parse it
    let exitString: LimitedString =
      try:
        initLimitedString(capacity = maxLength, text = "exit")
      except CapacityError:
        return
    var
      inputChar: char = '\0'
      resultString: LimitedString = emptyLimitedString(capacity = maxLength)
      cursorPosition: Natural = 0
    # Read the user input until not meet new line character or the input
    # reach the maximum length
    while inputChar.ord != 13 and resultString.len < maxLength:
      # Get the next character from the user's input
      try:
        inputChar = getch()
      except IOError:
        showError(message = "Can't get the next character. Reason: ",
            e = getCurrentException())
        return exitString
      # Backspace pressed, delete the last character from the user input
      if inputChar.ord == 127:
        # Input is empty or cursor is at first position, do nothing
        if cursorPosition == 0:
          continue
        try:
          stdout.cursorBackward(count = cursorPosition)
          stdout.write(s = repeat(c = ' ', runeLen(s = $resultString)))
          stdout.cursorBackward(count = runeLen(s = $resultString))
          deleteChar(inputString = resultString,
              cursorPosition = cursorPosition)
          stdout.write(s = $resultString)
          if cursorPosition < runeLen(s = $resultString):
            stdout.cursorBackward(count = runeLen(s = $resultString) - cursorPosition)
        except IOError, ValueError:
          showError(message = "Can't delete character. Reason: ",
              e = getCurrentException())
          return exitString
      # Special key pressed (all starts like Escape key), check which one
      elif inputChar.ord == 27:
        try:
          inputChar = getch()
        except IOError:
          showError(message = "Can't get the next character after Escape. Reason: ",
              e = getCurrentException())
          return exitString
        # Escape key pressed, return "exit" as input value
        if inputChar.ord == 27:
          return exitString
        # Cursor movement keys pressed
        elif inputChar in ['[', 'O']:
          try:
            inputChar = getch()
          except IOError:
            showError(message = "Can't get the next character after Escape. Reason: ",
                e = getCurrentException())
            return exitString
          moveCursor(inputChar = inputChar, cursorPosition = cursorPosition,
              inputString = resultString)
        else:
          continue
      # Visible character, add it to the user input string and show it in the
      # console
      elif inputChar.ord > 31:
        let inputRune: string = readChar(inputChar = inputChar)
        try:
          stdout.write(s = inputRune)
        except IOError:
          showError(message = "Can't print entered character. Reason: ",
              e = getCurrentException())
        updateInput(cursorPosition = cursorPosition, inputString = resultString,
            insertMode = false, inputRune = inputRune)
    try:
      stdout.writeLine(x = "")
    except IOError:
      showError(message = "Can't add a new line. Reason: ",
          e = getCurrentException())
      return exitString
    return resultString

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
  userInput.next
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
      of cmdLongOption, cmdShortOption:
        if userInput.kind == cmdLongOption:
          result.add(y = "-")
        result.add(y = "-" & key)
        if userInput.val.len > 0:
          result.add(y = "=")
          if userInput.val.contains(sub = " "):
            result.add(y = "\"" & userInput.val & "\"")
          else:
            result.add(userInput.val)
      of cmdArgument:
        result.add(y = key)
      of cmdEnd:
        discard
      result.add(y = " ")
      userInput.next
    except CapacityError:
      break
  try:
    result.text = strutils.strip(s = $result)
  except CapacityError:
    return
