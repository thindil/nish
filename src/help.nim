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
import std/[algorithm, db_sqlite, os, parsecfg, strutils, streams, terminal]
# External modules imports
import contracts
# Internal imports
import columnamount, commandslist, constants, input, lstring, output, resultcode

using
  db: DbConn # Connection to the shell's database
  helpContent: ref HelpTable # The content of the help system

proc updateHelpEntry*(topic, usage, plugin: UserInput; content: string;
    db): ResultCode {.gcsafe, sideEffect, raises: [], tags: [ReadDbEffect,
    WriteDbEffect, WriteIOEffect], locks: 0, contractual.} =
  ## FUNCTION
  ##
  ## Update the help entry in the help table in the shell's database
  ##
  ## PARAMETERS
  ##
  ## * topic   - the topic of the help. Used as search entry in help
  ## * usage   - the content of usage section in the help entry
  ## * content - the content of the help entry
  ## * db      - the connection to the shell's database
  ##
  ## RETURNS
  ##
  ## QuitSuccess if the help entry was successfully updated in the database,
  ## otherwise QuitFailure and show message what wrong
  require:
    topic.len() > 0
    usage.len() > 0
    content.len() > 0
    plugin.len() > 0
    db != nil
  body:
    try:
      if db.getValue(query = sql(query = "SELECT topic FROM help WHERE topic=?"),
          topic).len() == 0:
        return showError(message = "Can't update the help entry for topic '" &
            topic & "' because there is no that topic.")
      db.exec(query = sql(query = "UPDATE help SET usage=?, content=?, plugin=? WHERE topic=?"),
          usage, content, plugin, topic)
      return QuitSuccess.ResultCode
    except DbError:
      return showError(message = "Can't update the help entry in the database. Reason: ",
          e = getCurrentException())

proc updateHelp*(helpContent; db) {.gcsafe, sideEffect, raises: [], tags: [
    ReadDbEffect, WriteIOEffect, ReadEnvEffect, TimeEffect, WriteDbEffect],
    contractual.} =
  ## FUNCTION
  ##
  ## Update the part of the shell's help content which depends on dynamic
  ## data, like the shell's options' values
  ##
  ## PARAMETERS
  ##
  ## * helpContent - the HelpTable with help content of the shell
  ## * db          - the connection to the shell's database
  require:
    db != nil
  body:
    let sortOrder: string = try:
          case db.getValue(query = sql(query = "SELECT value FROM options WHERE option='historySort'")):
          of "recent": "recently used"
          of "amount": "how many times used"
          of "name": "name"
          of "recentamount": "recently used and how many times"
          else:
            "unknown"
      except DbError:
        "recently used and how many times"
    let sortDirection: string = try:
          if db.getValue(query = sql(query = "SELECT value FROM options WHERE option='historyReverse'")) ==
                "true": " in reversed order." else: "."
      except DbError:
        "."
    try:
      discard updateHelpEntry(topic = initLimitedString(capacity = 13,
          text = "history list"), usage = initLimitedString(capacity = 39,
          text = "history list ?amount? ?order? ?reverse?"),
          plugin = initLimitedString(capacity = 4, text = "Help"),
          content = "Show the last " & db.getValue(query = sql(
          query = "SELECT value FROM options WHERE option='historyAmount'")) &
          " commands from the shell's history ordered by " & sortOrder &
          sortDirection &
          " You can also set the amount, order and direction of order of commands to show by adding optional parameters amount, order and reverse. For example, to show the last 10 commands sorted by name in reversed order: history list 10 name true. Available switches for order are: amount, recent, name, recentamount. Available values for reverse are true or false.", db = db)
    except DbError, CapacityError:
      discard showError(message = "Can't update the shell's help. Reason: ",
          e = getCurrentException())

proc showUnknownHelp*(subCommand, command,
    helpType: UserInput): ResultCode {.gcsafe, sideEffect, raises: [], tags: [
    WriteIOEffect, ReadEnvEffect, TimeEffect], contractual.} =
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
  require:
    subCommand.len() > 0
    command.len() > 0
    helpType.len() > 0
  body:
    return showError(message = "Unknown subcommand `" & subCommand &
                "` for `" & command & "`. To see all available " & helpType &
                " commands, type `" & command & "`.")

proc showHelp*(topic: UserInput; helpContent: ref HelpTable;
    db): ResultCode {.gcsafe, sideEffect, raises: [], tags: [ReadIOEffect,
    WriteIOEffect, ReadDbEffect, WriteDbEffect, ReadEnvEffect, TimeEffect],
    contractual.} =
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
  require:
    db != nil
  body:
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

    result = ResultCode(QuitSuccess)
    if topic.len == 0:
      var
        i: Positive = 1
        keys: seq[string]
        mainHelp = HelpEntry(usage: "", content: "")
      try:
        for key in db.getAllRows(query = sql(query = "SELECT topic FROM help")):
          keys.add(y = key[0])
      except DbError:
        return showError(message = "Can't get help topics from database. Reason: ",
            e = getCurrentException())
      keys.sort(cmp = system.cmp)
      mainHelp.usage.add(y = "\n    ")
      for key in keys:
        mainHelp.usage.add(y = alignLeft(s = key, count = 20))
        i.inc()
        if i == 4:
          mainHelp.usage.add(y = "\n    ")
          i = 1
      mainHelp.usage.removeSuffix(suffix = ", ")
      mainHelp.content.add(y = "To see more information about the selected topic, type help [topic], for example: help cd.")
      showHelpEntry(helpEntry = mainHelp, usageHeader = "Available help topics")
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
        dbHelp = try:
            db.getRow(query = sql(query = "SELECT usage, content FROM help WHERE topic=?"), key)
          except DbError:
            return showError(message = "Can't read help content from database. Reason: ",
                e = getCurrentException())
      if dbHelp[0].len() > 0:
        showHelpEntry(helpEntry = HelpEntry(usage: dbHelp[0], content: dbHelp[1]))
      else:
        if args.len() > 0:
          try:
            result = showUnknownHelp(subCommand = args, command = command,
                helpType = initLimitedString(capacity = maxInputLength, text = (
                    if command == "alias": "aliases" else: $command)))
          except CapacityError:
            return showError(message = "Can't show help for unknown command")
        else:
          return showError(message = "Unknown help topic. For the list of available help topics, type 'help'.")

proc showHelpList*(command: string; subcommands: openArray[
    string]): ResultCode {.gcsafe, sideEffect, raises: [], tags: [ReadDbEffect,
    WriteDbEffect, ReadIOEffect, WriteIOEffect, ReadEnvEffect, TimeEffect],
    contractual.} =
  ## FUNCTION
  ##
  ## Show short help about available subcommands related to the selected command
  ##
  ## PARAMETERS
  ##
  ## * command     - the selected command which subcommands' list will be
  ##                 displayed
  ## * subcommands - the list of subcommands available for the selected command
  ##
  ## RETURNS
  ##
  ## This procedure always return QuitSuccess
  body:
    showOutput(message = indent(s = "Available subcommands for '" & command &
        "' are': ", count = 4), fgColor = fgYellow)
    showOutput(message = indent(s = subcommands.join(sep = ", "), count = 6))
    showOutput(message = " ")
    showOutput(message = indent(s = "To see more information about the subcommands, type 'help " &
        command & " [subcommand]',", count = 4))
    showOutput(message = indent(s = "for example: 'help " & command & " " &
        subcommands[0] & "'.", count = 4))
    return QuitSuccess.ResultCode

proc initHelp*(helpContent; db; commands: ref CommandsList) {.gcsafe,
    sideEffect, raises: [], tags: [WriteIOEffect, TimeEffect, ReadEnvEffect,
    ReadDbEffect, ReadIOEffect, WriteDbEffect, RootEffect], contractual.} =
  ## FUNCTION
  ##
  ## Initialize the help system. Update some help entries with current the
  ## shell's settings and add the help related commands to the shell's
  ## commands' list.
  ##
  ## PARAMETERS
  ##
  ## * helpContent - the HelpTable with help content of the shell
  ## * db          - the connection to the shell's database
  ## * commands    - the list of the shell's commands
  require:
    db != nil
  body:
    updateHelp(helpContent = helpContent, db = db)
    proc helpCommand(arguments: UserInput; db: DbConn;
        list: CommandLists): ResultCode {.gcsafe, raises: [], contractual.} =
      ## FUNCTION
      ##
      ## The code of the shell's command "help"
      ##
      ## PARAMETERS
      ##
      ## * arguments - the arguments entered by the user for the command
      ## * db        - the connection to the shell's database
      ## * list      - the additional data for the command, like list of help
      ##               entries, etc
      ##
      ## RETURNS
      ## QuitSuccess if the selected help's topic was succesully shown, otherwise
      ## QuitFailure.
      body:
        return showHelp(topic = arguments, helpContent = list.help, db = db)

    try:
      addCommand(name = initLimitedString(capacity = 4, text = "help"),
          command = helpCommand, commands = commands)
    except CapacityError, CommandsListError:
      showError(message = "Can't add commands related to the shell's help. Reason: ",
          e = getCurrentException())

proc addHelpEntry*(topic, usage, plugin: UserInput; content: string;
    isTemplate: bool; db): ResultCode {.gcsafe, sideEffect, raises: [], tags: [
    ReadDbEffect, WriteDbEffect, WriteIOEffect], locks: 0, contractual.} =
  ## FUNCTION
  ##
  ## Add a new help entry to the help table in the shell's database
  ##
  ## PARAMETERS
  ##
  ## * topic   - the topic of the help. Used as search entry in help
  ## * usage   - the content of usage section in the help entry
  ## * content - the content of the help entry
  ## * db      - the connection to the shell's database
  ##
  ## RETURNS
  ##
  ## QuitSuccess if the help entry was successfully added to the database,
  ## otherwise QuitFailure and show message what wrong
  require:
    topic.len() > 0
    usage.len() > 0
    content.len() > 0
    plugin.len() > 0
    db != nil
  body:
    try:
      if db.getValue(query = sql(query = "SELECT topic FROM help WHERE topic=?"),
          topic).len() > 0:
        return showError(message = "Can't add help entry for topic '" & topic & "' because there is one.")
      db.exec(query = sql(query = "INSERT INTO help (topic, usage, content, plugin, template) VALUES (?, ?, ?, ?, ?)"),
          topic, usage, content, plugin, (if isTemplate: 1 else: 0))
      return QuitSuccess.ResultCode
    except DbError:
      return showError(message = "Can't add help entry to database. Reason: ",
          e = getCurrentException())

proc createHelpDb*(db): ResultCode {.gcsafe, sideEffect, raises: [], tags: [
    WriteDbEffect, ReadDbEffect, WriteIOEffect, ReadIOEffect, RootEffect],
    contractual.} =
  ## FUNCTION
  ##
  ## Create the table help and fill it with help entries from the configuration
  ## file
  ##
  ## PARAMETERS
  ##
  ## * db - the connection to the shell's database
  ##
  ## RETURNS
  ##
  ## QuitSuccess if creation was successfull, otherwise QuitFailure and
  ## show message what wrong
  require:
    db != nil
  body:
    # Create table help in the shell's database
    try:
      db.exec(query = sql(query = """CREATE TABLE help (
                   topic       VARCHAR(""" & $maxInputLength &
              """) NOT NULL PRIMARY KEY,
                   usage       VARCHAR(""" & $maxInputLength &
              """) NOT NULL,
                   content     TEXT NOT NULL,
                   plugin      VARCHAR(""" & $maxInputLength &
            """) NOT NULL,
                   template     BOOLEAN NOT NULL)"""))
    except DbError, CapacityError:
      return showError(message = "Can't create 'help' table. Reason: ",
          e = getCurrentException())
    result = QuitSuccess.ResultCode
    # Read the help entries from the configuration file and add them to
    # the database
    let helpFile = "help" & DirSep & "help.cfg"
    var
      file = newFileStream(helpFile, fmRead)
      parser: CfgParser
    try:
      open(parser, file, helpFile)
    except OSError, IOError, Exception:
      return showError(message = "Can't read file with help entries. Reason: ",
          e = getCurrentException())
    var
      topic, usage, content, plugin: string = ""
      isTemplate: bool = false
    proc addEntry(): ResultCode {.gcsafe, sideEffect, raises: [], tags: [
        ReadDbEffect, WriteDbEffect, WriteIOEffect], contractual.} =
      ## FUNCTION
      ##
      ## Add the selected help entry to the database and reset values of
      ## variables used to set it
      ##
      ## RETURNS
      ##
      ## QuitSuccess if the help entry was properly added, otherwise
      ## QuitFailure with information what goes wrong.
      body:
        if topic.len() > 0 and usage.len() > 0 and content.len() > 0 and
            plugin.len() > 0:
          try:
            result = addHelpEntry(topic = initLimitedString(
                capacity = maxInputLength, text = topic),
                usage = initLimitedString(
                capacity = maxInputLength, text = usage),
                plugin = initLimitedString(capacity = maxInputLength,
                text = plugin), content = content, isTemplate = isTemplate, db = db)
          except CapacityError:
            return showError(message = "Can't add help entry. Reason: ",
                e = getCurrentException())
          topic = ""
          usage = ""
          content = ""
          plugin = ""
          isTemplate = false
    # Read the help configuration file
    while true:
      try:
        let entry = parser.next()
        case entry.kind
        of cfgSectionStart:
          if plugin.len() == 0:
            plugin = entry.section
            continue
          result = addEntry()
          plugin = entry.section
        of cfgEof:
          result = addEntry()
          break
        of cfgKeyValuePair, cfgOption:
          case entry.key
          of "topic":
            topic = entry.value
          of "usage":
            usage = entry.value
          of "content":
            content = entry.value
          of "template":
            isTemplate = true
          else:
            discard
        of cfgError:
          echo entry.msg
          result = QuitFailure.ResultCode
      except IOError, OSError, ValueError, CapacityError:
        return showError(message = "Can't get help entry from configuration file. Reason: ",
            e = getCurrentException())
    try:
      close(parser)
    except IOError, OSError, Exception:
      return showError(message = "Can't close file with help entries. Reason: ",
          e = getCurrentException())

proc deleteHelpEntry*(topic: UserInput; db): ResultCode {.gcsafe, sideEffect,
    raises: [], tags: [ReadDbEffect, WriteDbEffect, WriteIOEffect], locks: 0,
    contractual.} =
  ## FUNCTION
  ##
  ## Delete the help entry from the help table in the shell's database
  ##
  ## PARAMETERS
  ##
  ## * topic   - the topic of the help. Used as search entry in help
  ## * db      - the connection to the shell's database
  ##
  ## RETURNS
  ##
  ## QuitSuccess if the help entry was successfully deleted from the database,
  ## otherwise QuitFailure and show message what wrong
  require:
    topic.len() > 0
    db != nil
  body:
    try:
      if db.getValue(query = sql(query = "SELECT topic FROM help WHERE topic=?"),
          topic).len() == 0:
        return showError(message = "Can't delete the help entry for topic '" &
            topic & "' because there is no that topic.")
      db.exec(query = sql(query = "DELETE FROM help WHERE topic=?"), topic)
      return QuitSuccess.ResultCode
    except DbError:
      return showError(message = "Can't delete the help entry in the database. Reason: ",
          e = getCurrentException())
