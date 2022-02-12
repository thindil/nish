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

import std/[db_sqlite, parseopt, strutils, tables]
import history, options, output

func updateHelp*(helpContent: var Table[string, string], db: DbConn) {.gcsafe,
    raises: [DbError], tags: [ReadDbEffect].} =
  ## Update the part of the shell's help content which depends on dynamic
  ## data, like the shell's options' values
  helpContent["history show"] = """
        Usage: history show

        Show the last """ & getOption("historyAmount", db) & """ commands from the shell's history.
        """

proc showUnknownHelp*(subCommand, Command, helpType: string): int {.gcsafe,
    sideEffect, raises: [IOError, ValueError], tags: [WriteIOEffect].} =
  return showError("Unknown subcommand `" & subCommand &
              "` for `" & Command & "`. To see all available " & helpType &
              " commands, type `" & Command & "`.")

proc showHelp*(userInput: var OptParser; helpContent: var Table[string, string],
    db: DbConn): int =
  ## Show the selected help section. If the user entered non-existing name of
  ## the help section, show info about it.
  result = QuitSuccess
  userInput.next()
  if userInput.kind == cmdEnd:
    showOutput(helpContent["help"])
    discard updateHistory("help", db)
  else:
    let
      args = join(userInput.remainingArgs(), " ")
      key = userInput.key & (if args.len() > 0: " " & args else: "")
    if helpContent.hasKey(key):
      showOutput(helpContent[key])
      discard updateHistory("help " & key, db)
    elif helpContent.hasKey(userInput.key):
      if key == userInput.key:
        showOutput(helpContent[userInput.key])
        discard updateHistory("help " & userInput.key, db)
      else:
        result = showUnknownHelp(args, userInput.key, (if userInput.key ==
            "alias": "aliases" else: userInput.key))
        discard updateHistory("help " & key, db, result)
    else:
      result = showError("Uknown command '" & key & "'")
      discard updateHistory("help " & key, db, result)
