# Copyright © 2024 Bartek Jasicki
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

## Provides unit tests for input module

import utils/utils
import unittest2, nimalyzer
include ../src/input
when defined(testInput):
  import ../src/theme
  import nimalyzer

suite "Unit tests for input module":

  checkpoint "Initializing the tests"
  let db: DbConn = initDb(dbName = "test8.db")

  test "Getting the command's arguments":
    {.ruleOff: "varUplevel".}
    var
      userCommand: OptParser = initOptParser(
          cmdline = "ls -ab --foo --bar=20 file.txt")
      conjCommands: bool = true
      arguments: UserInput = getArguments(userInput = userCommand,
          conjCommands = conjCommands)
    {.ruleOn: "varUplevel".}
    check:
      arguments == "ls -ab --foo --bar=20 file.txt"

  test "Reading the user's input":
    when defined(testInput):
      echo "exit"
      check:
        readInput(db = db) == "exit"
    else:
      skip()

  test "Reading a lowercase character":
    check:
      readChar(inputChar = 'c', db = db) == "c"

  test "Reading a uppercase character":
    check:
      readChar(inputChar = 'H', db = db) == "H"

  test "Deleting a character":
    var
      inputString: UserInput = "my text"
      cursorPosition: Natural = 1
    deleteChar(inputString = inputString, cursorPosition = cursorPosition)
    check:
      inputString == "y text"
      cursorPosition == 0

  test "Moving the cursor":
    const inputString: UserInput = "my text"
    var cursorPosition: Natural = 1
    moveCursor(inputChar = 'D', cursorPosition = cursorPosition,
        inputString = inputString, db = db)
    check:
      cursorPosition == 0

  test "Updating the user's input":
    var
      inputString: UserInput = "my text"
      cursorPosition: Natural = 7
    updateInput(cursorPosition = cursorPosition, inputString = inputString,
        insertMode = false, inputRune = "a")
    check:
      inputString == "my texta"
      cursorPosition == 8

  test "Asking user for a name from the list":
    when defined(testInput):
      var color: Color = newColor()
      askForName[Color](db = db, action = "Testing", namesType = "color", name = color)
      echo color.description
      check:
        color != newColor()
    else:
      skip()
