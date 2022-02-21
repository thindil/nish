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
import constants

proc readInput*(maxLength: int = maxInputLength): string {.gcsafe, sideEffect,
    raises: [IOError, ValueError], tags: [WriteIOEffect, ReadIOEffect].} =
  ## Read the user input. Used in adding a new or editing an existing alias
  ## or environment variable
  # Get the user input and parse it
  var inputChar = '\0'
  # Read the user input until not meet new line character or the input
  # reach the maximum length
  while inputChar.ord() != 13 and result.len() < maxLength:
    # Backspace pressed, delete the last character from the user input
    if inputChar.ord() == 127:
      if result.len() > 0:
        result = result[0..^2]
        stdout.cursorBackward()
        stdout.write(" ")
        stdout.cursorBackward()
    elif inputChar.ord() == 27:
      inputChar = getch()
      if inputChar.ord() == 27:
        return "exit"
      else:
        continue
    # Visible character, add it to the user input string and show it in the
    # console
    elif inputChar.ord() > 31:
      stdout.write(inputChar)
      result.add(inputChar)
    inputChar = getch()
  stdout.writeLine("")

proc getArguments*(userInput: var OptParser; conjCommands: var bool): string =
  ## Set the command arguments from the user input
  userInput.next()
  conjCommands = false
  while userInput.kind != cmdEnd:
    if userInput.key == "&&":
      conjCommands = true
      break
    if userInput.key == "||":
      break
    case userInput.kind
    of cmdLongOption:
      result.add("--" & userInput.key & "=" & userInput.val)
    of cmdShortOption:
      result.add("-" & userInput.key)
    of cmdArgument:
      result.add(userInput.key)
    of cmdEnd:
      discard
    result.add(" ")
    userInput.next()
  result = strip(result)
