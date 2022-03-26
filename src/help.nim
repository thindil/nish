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

import std/[algorithm, db_sqlite, os, strutils, tables, terminal]
import constants, history, options, output

using
  db: DbConn # Connection to the shell's database
  helpContent: var HelpTable # The content of the help system

proc updateHelp*(helpContent; db) {.gcsafe, sideEffect,
    raises: [], tags: [ReadDbEffect, WriteIOEffect, ReadEnvEffect,
        TimeEffect].} =
  ## FUNCTION
  ##
  ## Update the part of the shell's help content which depends on dynamic
  ## data, like the shell's options' values
  ##
  ## PARAMETERS
  ## * helpContent - the HelpTable with help content of the shell
  ## * db          - the connection to the shell's database
  ##
  ## RETURNS
  ## The argument helpContent with updated help for command 'history show'.
  helpContent["history show"] = HelpEntry(usage: "history show",
      content: "Show the last " & getOption("historyAmount", db) & " commands from the shell's history.")

proc showUnknownHelp*(subCommand, Command, helpType: string): int {.gcsafe,
    sideEffect, raises: [], tags: [WriteIOEffect, ReadEnvEffect, TimeEffect].} =
  return showError("Unknown subcommand `" & subCommand &
              "` for `" & Command & "`. To see all available " & helpType &
              " commands, type `" & Command & "`.")

proc showHelp*(topic: string; helpContent: HelpTable; db): int {.gcsafe,
    sideEffect, raises: [], tags: [ReadIOEffect, WriteIOEffect, ReadDbEffect,
    WriteDbEffect, ReadEnvEffect, TimeEffect].} =
  ## Show the selected help section. If the user entered non-existing name of
  ## the help section, show info about it.

  proc showHelpEntry(helpEntry: HelpEntry;
      usageHeader: string = "Usage") {.gcsafe, sideEffect, raises: [], tags: [
      ReadIOEffect, WriteIOEffect, ReadDbEffect, ReadEnvEffect, TimeEffect,
      WriteDbEffect].} =
    ## Show the selected help entry
    showOutput(message = "    " & usageHeader & ": ", newLine = false,
        fgColor = fgYellow)
    showOutput(helpEntry.usage & "\n")
    var
      content: string = "    "
      index: Positive = 4
    let maxLength: int = (try: terminalWidth() - 8 except ValueError: 72);
    for ch in helpEntry.content:
      content.add(ch)
      index.inc()
      if index == maxLength:
        content.add("\n    ")
        index = 4
    showOutput(content)
    discard updateHistory("help", db)

  result = QuitSuccess
  if topic.len == 0:
    try:
      showHelpEntry(helpContent["help"], "Available help topics")
    except KeyError as e:
      return showError("Can't show list of available help topics. Reason: " & e.msg)
  else:
    let
      tokens: seq[string] = split(topic)
      args: string = join(tokens[1 .. ^1], " ")
      command: string = tokens[0]
      key: string = command & (if args.len() > 0: " " & args else: "")
    if helpContent.hasKey(key):
      try:
        showHelpEntry(helpContent[key])
      except KeyError as e:
        return showError("Can't show the help topic for '" & key &
            "'. Reason: " & e.msg)
    elif helpContent.hasKey(command):
      if key == command:
        try:
          showHelpEntry(helpContent[command])
        except KeyError as e:
          return showError("Cam't show the help topic for '" & command &
              "'. Reason: " & e.msg)
      else:
        result = showUnknownHelp(args, command, (if command ==
            "alias": "aliases" else: command))
        discard updateHistory("help " & key, db, result)
    else:
      result = showError("Unknown help topic '" & key & "'")
      discard updateHistory("help " & key, db, result)

proc setMainHelp*(helpContent) {.gcsafe, sideEffect, raises: [],
    tags: [WriteIOEffect, TimeEffect, ReadEnvEffect].} =
  ## Set the content of the main help screen
  helpContent["help"] = HelpEntry(usage: "\n    ")
  var
    i: Positive = 1
    keys: seq[string]
  for key in helpContent.keys:
    keys.add(key)
  keys.sort(system.cmp)
  for key in keys:
    try:
      helpContent["help"].usage.add(alignLeft(key, 20))
    except KeyError as e:
      discard showError("Can't set content of the help main screen. Reason: " & e.msg)
      return
    i.inc()
    if i == 4:
      try:
        helpContent["help"].usage.add("\n    ")
      except KeyError as e:
        discard showError("Can't set content of the help main screen. Reason: " & e.msg)
        return
      i = 1
  try:
    helpContent["help"].usage.removeSuffix(", ")
    helpContent["help"].content.add("To see more information about the selected topic, type help [topic], for example: help cd.")
  except KeyError as e:
    discard showError("Can't set content of the help main screen. Reason: " & e.msg)
    return
