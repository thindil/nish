# Copyright © 2022-2024 Bartek Jasicki
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

## This module provides code to handle the user's input in the shell, like
## getting the Unicode character, deleting characters or moving cursor around.

# Standard library imports
import std/[parseopt, strutils, terminal, unicode]
# External modules imports
import contracts, nancy, termstyle
import norm/sqlite
# Internal imports
import constants, output, theme, types

type MaxInputLength* = range[1..maxInputLength]
  ## Used to store maximum allowed length of the user input

using db: DbConn # Connection to the shell's database

proc readChar*(inputChar: char; db): string {.sideEffect, raises: [], tags: [
    WriteIOEffect, ReadIOEffect, RootEffect], contractual.} =
  ## Read the Unicode character from the user's input
  ##
  ## * inputChar - the last printable character entered by the user
  ## * db        - the connection to the shell's database
  ##
  ## Returns the string with full Unicode character entered by the user
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
          e = getCurrentException(), db = db)

proc deleteChar*(inputString: var UserInput;
    cursorPosition: var Natural) {.sideEffect, raises: [], tags: [WriteIOEffect,
    RootEffect], contractual.} =
  ## Delete the Unicode character at the selected position from the user's input
  ##
  ## * inputString    - the string of characters entered by the user
  ## * cursorPosition - the position of the cursor in the string
  ##
  ## Returns modified inputString and the new cursor position as cursorPosition
  body:
    var runes: seq[Rune] = toRunes(s = $inputString)
    cursorPosition.dec
    runes.delete(i = cursorPosition)
    inputString = $runes

proc moveCursor*(inputChar: char; cursorPosition: var Natural;
    inputString: UserInput; db) {.sideEffect, raises: [], tags: [WriteIOEffect,
    RootEffect], contractual.} =
  ## Move the cursor inside the user's input
  ##
  ## * inputChar      - the last ASCII character entered by the user
  ## * cursorPosition - the current position of cursor in the user's input
  ## * inputString    - the user's input's content
  ## * db             - the connection to the shell's database
  ##
  ## Returns the new position of the cursor as modified cursorPosition argument
  body:
    try:
      case inputChar
      # Arrow left key pressed
      of 'D':
        if cursorPosition > 0:
          stdout.cursorBackward
          cursorPosition.dec
      # Arrow right key pressed
      of 'C':
        if cursorPosition < runeLen(s = $inputString):
          stdout.cursorForward
          cursorPosition.inc
      # Home key pressed
      of 'H':
        if cursorPosition > 0:
          stdout.cursorBackward(count = cursorPosition)
          cursorPosition = 0
      # End key pressed
      of 'F':
        if cursorPosition < runeLen(s = $inputString):
          stdout.cursorForward(count = runeLen(s = $inputString) - cursorPosition)
          cursorPosition = runeLen(s = $inputString)
      else:
        discard
    except IOError, ValueError, OSError:
      showError(message = "Can't move the cursor. Reason: ",
          e = getCurrentException(), db = db)

proc updateInput*(cursorPosition: var Natural; inputString: var UserInput;
    insertMode: bool; inputRune: string) {.sideEffect, raises: [], tags: [
    WriteIOEffect, RootEffect], contractual.} =
  ## Update the user's input with the new Unicode character
  ##
  ## * cursorPosition - the current position of cursor in the user's input
  ## * inputString    - the user's input's content
  ## * insertMode     - if true, the input is in the insert (replace) mode
  ## * inputRune      - the Unicode character to enter to the user's input
  ##
  ## Returns the new cursor position as modified cursorPosition and the modified user's
  ## input's content as inputString
  if inputString.runeLen + 1 > maxInputLength:
    return
  if cursorPosition < runeLen(s = $inputString):
    if insertMode:
      var runes: seq[Rune] = toRunes(s = $inputString)
      runes[cursorPosition] = inputRune.toRunes[0]
      inputString = $runes
    else:
      var runes: seq[Rune] = toRunes(s = $inputString)
      runes.insert(item = inputRune.toRunes[0], i = cursorPosition)
      inputString = $runes
      cursorPosition.inc
  else:
    inputString.add(y = inputRune)
    cursorPosition.inc

proc readInput*(maxLength: MaxInputLength = maxInputLength;
    db): UserInput {.sideEffect, raises: [], tags: [WriteIOEffect, ReadIOEffect,
        TimeEffect, RootEffect],
    contractual.} =
  ## Read the user input. Used in adding a new or editing an existing alias
  ## or environment variable
  ##
  ## * maxLength - the maximum length of the user input to parse. Default value
  ##               is the constant maxInputLength
  ## * db        - the connection to the shell's database
  ##
  ## Returns the user input text or "exit" if there was an error or the user pressed
  ## Escape key
  body:
    # Get the user input and parse it
    const exitString: string = "exit"
    var
      inputChar: char = '\0'
      resultString: string = ""
      cursorPosition: Natural = 0
    # Read the user input until not meet new line character or the input
    # reach the maximum length
    while inputChar.ord != 13 and resultString.len < maxLength:
      # Get the next character from the user's input
      try:
        inputChar = getch()
      except IOError:
        showError(message = "Can't get the next character. Reason: ",
            e = getCurrentException(), db = db)
        return exitString
      # Backspace pressed, delete the last character from the user input
      if inputChar.ord in {8, 127}:
        # Input is empty or cursor is at first position, do nothing
        if cursorPosition == 0:
          continue
        try:
          stdout.cursorBackward(count = cursorPosition)
          stdout.write(s = repeat(c = ' ', count = runeLen(s = $resultString)))
          stdout.cursorBackward(count = runeLen(s = $resultString))
          deleteChar(inputString = resultString,
              cursorPosition = cursorPosition)
          stdout.write(s = $resultString)
          if cursorPosition < runeLen(s = $resultString):
            stdout.cursorBackward(count = runeLen(s = $resultString) - cursorPosition)
        except IOError, ValueError, OSError:
          showError(message = "Can't delete character. Reason: ",
              e = getCurrentException(), db = db)
          return exitString
      # Special key pressed (all starts like Escape key), check which one
      elif inputChar.ord == 27:
        try:
          inputChar = getch()
        except IOError:
          showError(message = "Can't get the next character after Escape. Reason: ",
              e = getCurrentException(), db = db)
          return exitString
        # Escape key pressed, return "exit" as input value
        if inputChar.ord == 27:
          return exitString
        # Cursor movement keys or delete key pressed
        elif inputChar in ['[', 'O']:
          try:
            inputChar = getch()
            # Delete key pressed
            if inputChar == '3':
              if getch() == '~':
                stdout.cursorBackward(count = cursorPosition)
                stdout.write(s = repeat(c = ' ', count = runeLen(
                    s = $resultString)))
                stdout.cursorBackward(count = runeLen(s = $resultString))
                cursorPosition.inc
                deleteChar(inputString = resultString,
                    cursorPosition = cursorPosition)
                stdout.write(s = $resultString)
                if cursorPosition < runeLen(s = $resultString):
                  stdout.cursorBackward(count = runeLen(s = $resultString) - cursorPosition)
            # Cursor movement key pressed
            else:
              moveCursor(inputChar = inputChar, cursorPosition = cursorPosition,
                  inputString = resultString, db = db)
          except:
            showError(message = "Can't get the next character after Escape. Reason: ",
                e = getCurrentException(), db = db)
            return exitString
        else:
          continue
      # Visible character, add it to the user input string and show it in the
      # console
      elif inputChar.ord > 31:
        let inputRune: string = readChar(inputChar = inputChar, db = db)
        try:
          stdout.write(s = inputRune)
        except IOError:
          showError(message = "Can't print entered character. Reason: ",
              e = getCurrentException(), db = db)
        updateInput(cursorPosition = cursorPosition, inputString = resultString,
            insertMode = false, inputRune = inputRune)
    try:
      stdout.writeLine(x = "")
    except IOError:
      showError(message = "Can't add a new line. Reason: ",
          e = getCurrentException(), db = db)
      return exitString
    return resultString

proc getArguments*(userInput: var OptParser;
    conjCommands: var bool): UserInput {.sideEffect, raises: [], tags: [
    ReadIOEffect], contractual.} =
  ## Set the command arguments from the user input
  ##
  ## * userInput    - the input string entered by the user
  ## * conjCommands - if true, set the commands to run next only if the previous
  ##                  was successful, otherwise run the next command only when
  ##                  previous was failure
  ##
  ## Returns properly converted user input and parameter conjCommands
  body:
    result = ""
    conjCommands = false
    var
      arguments: seq[string] = userInput.remainingArgs
      index: int = -1
    for argument in arguments:
      index.inc
      if argument == "&&":
        conjCommands = true
        break
      if argument == "||":
        break
      if " " in argument:
        result.add(y = " \"" & argument & "\"")
      else:
        result.add(y = " " & argument)
    if index < arguments.len - 1:
      userInput = initOptParser(cmdline = arguments[index + 1..^1])
    else:
      userInput = initOptParser(cmdline = @[""])
    result = strutils.strip(s = result)

proc askForName*[T](db; action, namesType: string; name: var T) {.sideEffect,
    raises: [], tags: [ReadDbEffect, TimeEffect, ReadIOEffect, WriteIOEffect,
    RootEffect], contractual.} =
  ## Ask the user for the name of the type and returns its value
  ##
  ## * db        - the connection to the shell's database
  ## * action    - the name of the action which will be performed, used to show
  ##               error messages
  ## * namesType - the name of types, like "color", "option", etc.
  ## * name      - the value selected by the user from the list
  ##
  ## Returns the selected type value or empty value if there was an error or
  ## the user cancelled the selection.
  require:
    db != nil
    action.len > 0
    namesType.len > 0
  body:
    var
      table: TerminalTable = TerminalTable()
      names: seq[T] = @[name]
    try:
      {.ruleOff: "ifStatements".}
      when names is seq[Color]:
        db.select(objs = names, cond = "1 = 1 ORDER BY name ASC")
      elif names is seq[Option]:
        db.select(objs = names, cond = "readonly=0 ORDER BY option ASC")
      elif names is seq[Alias]:
        db.select(objs = names, cond = "1 = 1 ORDER BY name ASC")
      elif names is seq[Completion]:
        db.select(objs = names, cond = "1 = 1 ORDER BY command ASC")
      elif names is seq[Plugin]:
        db.select(objs = names, cond = "1 = 1 ORDER BY location ASC")
      elif names is seq[Variable]:
        db.select(objs = names, cond = "1 = 1 ORDER BY name ASC")
      {.ruleOn: "ifStatements".}
      if names.len == 0:
        showError(message = "There is no available " & namesType & " to show.", db = db)
        when names is seq[Completion]:
          name.command = ""
        elif names is seq[Plugin]:
          name.location = "".Path
        else:
          name.description = ""
        return
      showOutput(message = "The name of the " & namesType &
          ". Select its number from the list. Enter 'exit' to cancel the command.", db = db)
      var
        rowIndex: Natural = 0
        row: array[4, string] = ["", "", "", ""]
      for index, name in names:
        var itemName: string = ""
        {.ruleOff: "ifStatements".}
        when names is seq[Color]:
          itemName = $name.name
        elif names is seq[Option]:
          itemName = name.option
        elif names is seq[Alias]:
          itemName = name.name
        elif names is seq[Completion]:
          itemName = name.command
        elif names is seq[Plugin]:
          itemName = $name.location
        elif names is seq[Variable]:
          itemName = name.name
        {.ruleOn: "ifStatements".}
        row[rowIndex] = style(ss = "[" & $(index + 1) & "] ", style = getColor(
            db = db, name = ids)) & style(ss = itemName, style = getColor(
            db = db, name = values))
        rowIndex.inc
        if rowIndex == 4:
          table.add(parts = row)
          row = ["", "", "", ""]
          rowIndex = 0
      table.add(parts = row)
    except:
      showError(message = "Can't show the list of " & namesType & "s. Reason: ",
          e = getCurrentException(), db = db)
      when names is seq[Completion]:
        name.command = ""
      elif names is seq[Plugin]:
        name.location = "".Path
      else:
        name.description = ""
      return
    try:
      table.echoTable
    except:
      showError(message = "Can't show the list of " & namesType & "s. Reason: ",
          e = getCurrentException(), db = db)
      return
    showOutput(message = namesType.capitalize() & "'s number: ",
        newLine = false, db = db, color = promptColor)
    let id: UserInput = readInput(db = db)
    if id == "exit":
      showError(message = action & " cancelled.", db = db)
      when names is seq[Completion]:
        name.command = ""
      elif names is seq[Plugin]:
        name.location = "".Path
      else:
        name.description = ""
      return
    try:
      name = names[parseInt(s = $id) - 1]
    except:
      when names is seq[Completion]:
        name.command = ""
      elif names is seq[Plugin]:
        name.location = "".Path
      else:
        name.description = ""
      discard showError(message = action &
          " cancelled, invalid " & namesType & "'s number: '" & id & "'", db = db)
