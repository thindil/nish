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
import constants, history, input, lstring, options, output, resultcode

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
  ##
  ## * helpContent - the HelpTable with help content of the shell
  ## * db          - the connection to the shell's database
  ##
  ## RETURNS
  ##
  ## The argument helpContent with updated help for command 'history show'.
  helpContent["history show"] = try:
      HelpEntry(usage: "history show", content: "Show the last " & getOption(
          optionName = initLimitedString(capacity = 13, text = "historyAmount"),
          db = db) & " commands from the shell's history.")
    except CapacityError:
      HelpEntry(usage: "history show", content: "Show the last commands from the shell's history.")

proc showUnknownHelp*(subCommand, command,
    helpType: UserInput): ResultCode {.gcsafe, sideEffect, raises: [], tags: [
    WriteIOEffect, ReadEnvEffect, TimeEffect].} =
  ## FUNCTION
  ##
  ## Show information about unknown help topic entered by the user
  ##
  ## PARAMETERS
  ##
  ## * subCommand - the subcommand for which help was looking for entered by
  ##                the user
  ## * Command    - the command for which help was looking for enteted by the
  ##                user
  ## * helpType   - the type of help topic
  ##
  ## RETURNS
  ## Always QuitFailure.
  return showError(message = "Unknown subcommand `" & subCommand &
              "` for `" & command & "`. To see all available " & helpType &
              " commands, type `" & command & "`.")

proc showHelp*(topic: UserInput; helpContent: HelpTable;
    db): ResultCode {.gcsafe, sideEffect, raises: [], tags: [ReadIOEffect,
        WriteIOEffect, ReadDbEffect, WriteDbEffect, ReadEnvEffect,
            TimeEffect].} =
  ## FUNCTION
  ##
  ## Show the selected help section. If the user entered non-existing name of
  ## the help section, show info about it.
  ##
  ## PARAMETERS
  ##
  ## * topic       - the help's topic to show. If empty, show index of the
  ##                 shell's help
  ## * helpContent - the HelpTable with help content of the shell
  ## * db          - the connection to the shell's database
  ##
  ## RETURNS
  ##
  ## QuitSuccess if the selected help's topic was succesully shown, otherwise
  ## QuitFailure.

  proc showHelpEntry(helpEntry: HelpEntry;
      usageHeader: string = "Usage") {.gcsafe, sideEffect, raises: [], tags: [
      ReadIOEffect, WriteIOEffect, ReadDbEffect, ReadEnvEffect, TimeEffect,
      WriteDbEffect].} =
    ## FUNCTION
    ##
    ## Show the selected help entry
    ##
    ## PARAMETERS
    ##
    ## * helpEntry   - the help entry to show to the user
    ## * usageHeader - the sentence used as the first in the help entry's usage
    ##                 header. Default value is "Usage"
    showOutput(message = "    " & usageHeader & ": ", newLine = false,
        fgColor = fgYellow)
    showOutput(message = helpEntry.usage & "\n")
    var
      content: string = "    "
      index: Positive = 4
    let maxLength: ColumnAmount = try:
        (terminalWidth() - 8).ColumnAmount
      except ValueError:
          72.ColumnAmount;
    for ch in helpEntry.content:
      content.add(y = ch)
      index.inc()
      if index == maxLength.int:
        content.add(y = "\n    ")
        index = 4
    showOutput(message = content)
    discard updateHistory(commandToAdd = "help", db = db)

  result = ResultCode(QuitSuccess)
  if topic.len == 0:
    try:
      showHelpEntry(helpEntry = helpContent["help"],
          usageHeader = "Available help topics")
    except KeyError as e:
      return showError(message = "Can't show list of available help topics. Reason: " & e.msg)
  else:
    let
      tokens: seq[string] = split(s = $topic)
      args: UserInput = try:
          initLimitedString(capacity = maxInputLength, text = join(a = tokens[
              1 .. ^1], " "))
        except CapacityError:
          return showError(message = "Can't set arguments for help")
      command: UserInput = try:
          initLimitedString(capacity = maxInputLength, text = tokens[0])
        except CapacityError:
          return showError(message = "Can't set command for help")
      key: string = command & (if args.len() > 0: " " & args else: "")
    if helpContent.hasKey(key = key):
      try:
        showHelpEntry(helpEntry = helpContent[key])
      except KeyError as e:
        return showError(message = "Can't show the help topic for '" & key &
            "'. Reason: " & e.msg)
    elif helpContent.hasKey(key = $command):
      if command == key:
        try:
          showHelpEntry(helpEntry = helpContent[$command])
        except KeyError as e:
          return showError(message = "Cam't show the help topic for '" &
              command & "'. Reason: " & e.msg)
      else:
        try:
          result = showUnknownHelp(subCommand = args, command = command,
              helpType = initLimitedString(capacity = maxInputLength, text = (
                  if command == "alias": "aliases" else: $command)))
          discard updateHistory(commandToAdd = "help " & key, db = db,
              returnCode = result)
        except CapacityError:
          return showError(message = "Can't show help for unknown command")
    else:
      result = showError(message = "Unknown help topic '" & key & "'")
      discard updateHistory(commandToAdd = "help " & key, db = db,
          returnCode = result)

proc setMainHelp*(helpContent) {.gcsafe, sideEffect, raises: [],
    tags: [WriteIOEffect, TimeEffect, ReadEnvEffect].} =
  ## FUNCTION
  ##
  ## Set the content of the main help screen
  ##
  ## PARAMETERS
  ##
  ## * helpContent - the HelpTable with help content of the shell
  ##
  ## RETURNS
  ##
  ## Updated argument helpContent
  helpContent["help"] = HelpEntry(usage: "\n    ")
  var
    i: Positive = 1
    keys: seq[string]
  for key in helpContent.keys:
    keys.add(y = key)
  keys.sort(cmp = system.cmp)
  for key in keys:
    try:
      helpContent["help"].usage.add(y = alignLeft(s = key, count = 20))
    except KeyError as e:
      discard showError(message = "Can't set content of the help main screen. Reason: " & e.msg)
      return
    i.inc()
    if i == 4:
      try:
        helpContent["help"].usage.add(y = "\n    ")
      except KeyError as e:
        discard showError(message = "Can't set content of the help main screen. Reason: " & e.msg)
        return
      i = 1
  try:
    helpContent["help"].usage.removeSuffix(suffix = ", ")
    helpContent["help"].content.add(y = "To see more information about the selected topic, type help [topic], for example: help cd.")
  except KeyError as e:
    discard showError(message = "Can't set content of the help main screen. Reason: " & e.msg)
    return
