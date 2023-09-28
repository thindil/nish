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

## This module contains code related to the shell's help system, like reading
## the help content from file, searching for or printing it to the user.

# Standard library imports
import std/[algorithm, os, parsecfg, strutils, streams, terminal]
# Database library import, depends on version of Nim
when (NimMajor, NimMinor, NimPatch) >= (1, 7, 3):
  import db_connector/db_sqlite
else:
  import std/db_sqlite
# External modules imports
import ansiparse, contracts, nancy, nimalyzer
import norm/sqlite
# Internal imports
import commandslist, helpcontent, constants, lstring, output, resultcode

using db: db_sqlite.DbConn # Connection to the shell's database

proc newHelpEntry(topic: string = ""; usage: string = ""; content: string = "";
    plugin: string = ""; templ: bool = false): HelpEntry {.sideEffect, raises: [],
    tags: [], contractual.} =
  ## Create a new data structure for the shell's help's entry.
  ##
  ## * topic   - the topic of the help's entry
  ## * usage   - the usage information about the help's entry
  ## * content - the content of the help's entry
  ## * plugin  - the name of the plugin to which the help's entry belongs
  ## * templ   - if true, the help entry's is a template
  ##
  ## Returns the new data structure for the selected shell's help's entry.
  body:
    HelpEntry(topic: topic, usage: usage, content: content, plugin: plugin,
        `template`: templ)

proc updateHelpEntry*(topic, usage, plugin: UserInput; content: string; db;
    isTemplate: bool): ResultCode {.sideEffect, raises: [], tags: [ReadDbEffect,
    WriteDbEffect, WriteIOEffect, RootEffect], contractual.} =
  ## Update the help entry in the help table in the shell's database
  ##
  ## * topic   - the topic of the help. Used as search entry in help
  ## * usage   - the content of usage section in the help entry
  ## * content - the content of the help entry
  ## * db      - the connection to the shell's database
  ##
  ## Returns QuitSuccess if the help entry was successfully updated in the database,
  ## otherwise QuitFailure and show message what wrong
  require:
    topic.len > 0
    usage.len > 0
    content.len > 0
    plugin.len > 0
    db != nil
  body:
    try:
      var entry: HelpEntry = newHelpEntry(topic = $topic, usage = $usage,
          plugin = $plugin, content = content, templ = isTemplate)
      db.select(obj = entry, cond = "topic=?", params = $topic)
      if entry.topic.len == 0:
        return showError(message = "Can't update the help entry for topic '" &
            topic & "' because there is no that topic.")
      db.update(obj = entry)
      return QuitSuccess.ResultCode
    except:
      return showError(message = "Can't update the help entry in the database. Reason: ",
          e = getCurrentException())

proc showUnknownHelp*(subCommand, command,
    helpType: UserInput): ResultCode {.gcsafe, sideEffect, raises: [], tags: [
    WriteIOEffect, ReadEnvEffect, TimeEffect, RootEffect], contractual.} =
  ## Show information about unknown help topic entered by the user
  ##
  ## * subCommand - the subcommand for which help was looking for entered by
  ##                the user
  ## * Command    - the command for which help was looking for enteted by the
  ##                user
  ## * helpType   - the type of help topic
  ##
  ## Always returns QuitFailure.
  require:
    subCommand.len > 0
    command.len > 0
    helpType.len > 0
  body:
    return showError(message = "Unknown subcommand `" & subCommand &
                "` for `" & command & "`. To see all available " & helpType &
                " commands, type `" & command & "`.")

proc showHelp*(topic: UserInput; db): ResultCode {.sideEffect, raises: [
    ], tags: [ReadIOEffect, WriteIOEffect, ReadDbEffect, WriteDbEffect,
    ReadEnvEffect, TimeEffect, RootEffect], contractual.} =
  ## Show the selected help section. If the user entered non-existing name of
  ## the help section, show info about it.
  ##
  ## * topic       - the help's topic to show. If empty, show index of the
  ##                 shell's help
  ## * db          - the connection to the shell's database
  ##
  ## RETURNS
  ##
  ## Returns QuitSuccess if the selected help's topic was succesully shown, otherwise
  ## QuitFailure.
  require:
    db != nil
  body:
    proc showHelpEntry(helpEntry: HelpEntry) {.sideEffect, raises: [], tags: [
        WriteIOEffect, ReadEnvEffect, ReadIOEffect, RootEffect], contractual.} =
      ## FUNCTION
      ##
      ## Show the selected help entry
      ##
      ## PARAMETERS
      ##
      ## * helpEntry   - the help entry to show to the user
      body:
        showOutput(message = "Usage: ", fgColor = fgYellow,
            newLine = false)
        showOutput(message = helpEntry.usage & "\n")
        showOutput(message = helpEntry.content)

    type ShellOption = ref object
      value: string = ""

    proc showHelpList(keys: seq[ShellOption]) {.sideEffect, raises: [],
        tags: [WriteIOEffect, ReadEnvEffect, ReadIOEffect, RootEffect],
            contractual.} =
      ## Show the list of help topics
      ##
      ## * keys - The list of help topics to show
      require:
        keys.len > 0
      body:
        var
          i: Positive = 1
          row: string = ""
          table: TerminalTable = TerminalTable()
          option: ShellOption = ShellOption()
          columnAmount: Positive = 4
        try:
          db.rawSelect(qry = "SELECT value FROM options WHERE option='helpColumns'",
              obj = option)
          columnAmount = option.value.parseInt
        except:
          showError(message = "Can't get the shell's setting for amount of help list columns. Reason: ",
              e = getCurrentException())
        for key in keys:
          row = row & key.value & "\t"
          i.inc
          if i == columnAmount + 1:
            try:
              table.tabbed(row = row)
            except UnknownEscapeError, InsufficientInputError, FinalByteError:
              showError(message = "Can't show the help entries list. Reason: ",
                  e = getCurrentException())
            row = ""
            i = 1
        var width: int = 0
        for size in table.getColumnSizes(maxSize = int.high):
          width = width + size + 2
        showFormHeader(message = "Available help topics",
            width = width.ColumnAmount, db = db)
        try:
          table.echoTable(padding = 4)
        except IOError, Exception:
          showError(message = "Can't show the help entries list. Reason: ",
              e = getCurrentException())
        showOutput(message = "\n\nTo see more information about the selected topic, type help [topic], for example: help " &
            keys[0].value & ".")

    # If no topic was selected by the user, show the list of the help's topics
    if topic.len == 0:
      var keys: seq[ShellOption] = @[ShellOption()]
      try:
        db.rawSelect(qry = "SELECT topic FROM help", objs = keys)
      except:
        return showError(message = "Can't get help topics from database. Reason: ",
            e = getCurrentException())
      keys.sort(cmp = system.cmp)
      showHelpList(keys = keys)
      return QuitSuccess.ResultCode
    # Try to get the selected help topic from the database
    let
      tokens: seq[string] = split(s = $topic)
      args: UserInput = try:
          initLimitedString(capacity = maxInputLength, text = join(a = tokens[
              1 .. ^1], sep = " "))
        except CapacityError:
          return showError(message = "Can't set arguments for help")
      command: UserInput = try:
          initLimitedString(capacity = maxInputLength, text = tokens[0])
        except CapacityError:
          return showError(message = "Can't set command for help")
      key: string = (command & (if args.len > 0: " " &
          args else: "")).replace(sub = '*', by = '%')
    var dbHelp: seq[HelpEntry] = @[newHelpEntry()]
    try:
      db.select(objs = dbHelp, cond = "topic LIKE ?", params = key)
    except:
      return showError(message = "Can't read help content from database. Reason: ",
          e = getCurrentException())
    # It there are topic or topics which the user is looking for, show them
    if dbHelp.len > 0:
      # There is exactly one topic which the user is looking for, show it
      if dbHelp.len == 1:
        var content: string = dbHelp[0].content
        # The help content for the selected topic is template, convert some
        # variables in it to the proper values. At this moment only history list
        # need that conversion.
        if dbHelp[0].`template`:
          var historyOption: ShellOption = ShellOption()
          try:
            db.rawSelect(qry = "SELECT value FROM options WHERE option='historySort'",
                obj = historyOption)
          except:
            historyOption.value = "recentamount"
          let sortOrder: string = case historyOption.value:
            of "recent": "recently used"
            of "amount": "how many times used"
            of "name": "name"
            of "recentamount": "recently used and how many times"
            else:
              "unknown"
          try:
            db.rawSelect(qry = "SELECT value FROM options WHERE option='historyReverse'",
                obj = historyOption)
          except:
            historyOption.value = "false"
          let sortDirection: string = (if historyOption.value ==
              "true": " in reversed order." else: ".")
          try:
            db.rawSelect(qry = "SELECT value FROM options WHERE option='historyAmount'",
                obj = historyOption)
            content = replace(s = content, sub = "$1", by = historyOption.value)
            content = replace(s = content, sub = "$2", by = sortOrder)
            content = replace(s = content, sub = "$3", by = sortDirection)
          except:
            discard showError(message = "Can't set the shell's help. Reason: ",
                e = getCurrentException())
        # Show the help entry to the user
        showHelpEntry(helpEntry = HelpEntry(usage: dbHelp[0].usage,
            content: content))
        return QuitSuccess.ResultCode
      # There is a few topics which match the criteria, show the list of them
      var keys: seq[ShellOption] = @[ShellOption()]
      for row in dbHelp:
        keys.add(y = ShellOption(value: row.topic))
      keys.sort(cmp = system.cmp)
      showHelpList(keys = keys)
      return QuitSuccess.ResultCode
    # The user selected uknown topic, show the uknown command help entry
    if args.len > 0:
      try:
        result = showUnknownHelp(subCommand = args, command = command,
            helpType = initLimitedString(capacity = maxInputLength, text = (
                if command == "alias": "aliases" else: $command)))
      except CapacityError:
        return showError(message = "Can't show help for unknown command")
      return QuitSuccess.ResultCode
    # The user entered the help topic which doesn't exists
    return showError(message = "Unknown help topic: `" & topic & "`. For the list of available help topics, type `help`.")

proc showHelpList*(command: string; subcommands: openArray[
    string]): ResultCode {.gcsafe, sideEffect, raises: [], tags: [ReadDbEffect,
    WriteDbEffect, ReadIOEffect, WriteIOEffect, ReadEnvEffect, TimeEffect,
    RootEffect], contractual.} =
  ## Show short help about available subcommands related to the selected command
  ##
  ## * command     - the selected command which subcommands' list will be
  ##                 displayed
  ## * subcommands - the list of subcommands available for the selected command
  ##
  ## This procedure always return QuitSuccess
  body:
    showOutput(message = "Available subcommands for '" & command & "' are: ",
        fgColor = fgYellow)
    showOutput(message = subcommands.join(sep = ", "))
    showOutput(message = " ")
    showOutput(message = "To see more information about the subcommands, type 'help " &
        command & " [subcommand]', for example: 'help " & command & " " &
        subcommands[0] & "'.")
    return QuitSuccess.ResultCode

proc addHelpEntry*(topic, usage, plugin: UserInput; content: string;
    isTemplate: bool; db): ResultCode {.gcsafe, sideEffect, raises: [], tags: [
    ReadDbEffect, WriteDbEffect, WriteIOEffect, RootEffect], contractual.} =
  ## Add a new help entry to the help table in the shell's database
  ##
  ## * topic   - the topic of the help. Used as search entry in help
  ## * usage   - the content of usage section in the help entry
  ## * content - the content of the help entry
  ## * db      - the connection to the shell's database
  ##
  ## Returns QuitSuccess if the help entry was successfully added to the database,
  ## otherwise QuitFailure and show message what wrong
  require:
    topic.len > 0
    usage.len > 0
    content.len > 0
    plugin.len > 0
    db != nil
  body:
    try:
      if db.exists(T = HelpEntry, cond = "topic=?", params = $topic):
        return showError(message = "Can't add help entry for topic '" & topic & "' because there is one.")
      var newHelp = newHelpEntry(topic = $topic, usage = $usage,
          content = content, plugin = $plugin, templ = isTemplate)
      db.insert(obj = newHelp)
      return QuitSuccess.ResultCode
    except:
      return showError(message = "Can't add help entry to database. Reason: ",
          e = getCurrentException())

proc readHelpFromFile*(db): ResultCode {.raises: [], tags: [WriteIOEffect,
    ReadIOEffect, ReadDbEffect, WriteDbEffect, RootEffect], contractual.} =
  ## Read the help entries from the configuration file and add them to
  ## the shell's database
  ##
  ## * db - the connection to the shell's database
  ##
  ## Returns QuitSuccess if the help content was successfully added to the database,
  ## otherwise QuitFailure and show message what wrong
  require:
    db != nil
  body:
    result = QuitSuccess.ResultCode
    var file: StringStream = try:
          newStringStream(s = getAsset(path = "help/help.cfg"))
        except ValueError, OSError, IOError, Exception:
          return showError(message = "Can't read help content. Reason: ",
              e = getCurrentException())
    {.ruleOff: "varDeclared".}
    var parser: CfgParser
    {.ruleOn: "varDeclared".}
    try:
      open(c = parser, input = file, filename = "helpContent")
    except OSError, IOError, Exception:
      return showError(message = "Can't read file with help entries. Reason: ",
          e = getCurrentException())
    var
      topic, usage, content, plugin: string = ""
      isTemplate: bool = false
    proc addEntry(): ResultCode {.gcsafe, sideEffect, raises: [], tags: [
        ReadDbEffect, WriteDbEffect, WriteIOEffect, RootEffect], contractual.} =
      ## Add the selected help entry to the database and reset values of
      ## variables used to set it
      ##
      ## Returns QuitSuccess if the help entry was properly added, otherwise
      ## QuitFailure with information what goes wrong.
      body:
        if topic.len > 0 and usage.len > 0 and content.len > 0 and
            plugin.len > 0:
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
        let entry: CfgEvent = parser.next
        case entry.kind
        of cfgSectionStart:
          if plugin.len == 0:
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
          result = showError(message = "Can't read help entry from configuration file. Reason: " & entry.msg)
      except IOError, OSError, ValueError, CapacityError:
        return showError(message = "Can't get help entry from configuration file. Reason: ",
            e = getCurrentException())
    try:
      close(c = parser)
    except IOError, OSError, Exception:
      return showError(message = "Can't close file with help entries. Reason: ",
          e = getCurrentException())

proc updateHelp*(db): ResultCode {.sideEffect, raises: [], tags: [WriteIOEffect,
    ReadIOEffect, ReadDbEffect, WriteDbEffect, RootEffect], contractual.} =
  ## Clear the user help content and replace it with the default values
  ##
  ## * db - the connection to the shell's database
  ##
  ## Returns QuitSuccess if the help content was successfully updated, otherwise
  ## QuitFailure and show message what wrong
  require:
    db != nil
  body:
    try:
      sqlite.exec(db = db, query = sql(query = "DELETE FROM help"));
    except DbError:
      return showError(message = "Can't clear the help content. Reason: ",
          e = getCurrentException())
    result = readHelpFromFile(db = db)
    if result == QuitFailure:
      return
    showOutput(message = "The shell's help content successfully updated.",
        fgColor = fgGreen)

proc initHelp*(db; commands: ref CommandsList) {.sideEffect, raises: [], tags: [
    WriteIOEffect, TimeEffect, ReadEnvEffect, ReadDbEffect, ReadIOEffect,
    WriteDbEffect, RootEffect], contractual.} =
  ## Initialize the help system. Update some help entries with current the
  ## shell's settings and add the help related commands to the shell's
  ## commands' list.
  ##
  ## * db          - the connection to the shell's database
  ## * commands    - the list of the shell's commands
  require:
    db != nil
  body:
    {.ruleOff: "paramsUsed".}
    proc helpCommand(arguments: UserInput; db;
        list: CommandLists): ResultCode {.raises: [], tags: [WriteIOEffect,
        WriteDbEffect, TimeEffect, ReadIOEffect, ReadDbEffect, ReadEnvEffect,
        RootEffect], contractual.} =
      ## The code of the shell's command "help"
      ##
      ## * arguments - the arguments entered by the user for the command
      ## * db        - the connection to the shell's database
      ## * list      - the additional data for the command, like list of help
      ##               entries, etc
      ##
      ## Returns QuitSuccess if the selected help's topic was succesully shown, otherwise
      ## QuitFailure.
      require:
        db != nil
      body:
        return showHelp(topic = arguments, db = db)

    proc updateHelpCommand(arguments: UserInput; db;
        list: CommandLists): ResultCode {.raises: [], tags: [WriteIOEffect,
        WriteDbEffect, ReadIOEffect, ReadDbEffect, RootEffect], contractual.} =
      ## The code of the shell's command "updateHelp"
      ##
      ## * arguments - the arguments entered by the user for the command
      ## * db        - the connection to the shell's database
      ## * list      - the additional data for the command, like list of help
      ##               entries, etc
      ##
      ## Returns QuitSuccess if the help content was succesfully updated, otherwise
      ## QuitFailure.
      require:
        db != nil
      body:
        return updateHelp(db = db)
    {.ruleOn: "paramsUsed".}

    try:
      addCommand(name = initLimitedString(capacity = 4, text = "help"),
          command = helpCommand, commands = commands)
      addCommand(name = initLimitedString(capacity = 10, text = "updatehelp"),
          command = updateHelpCommand, commands = commands)
    except CapacityError, CommandsListError:
      showError(message = "Can't add commands related to the shell's help. Reason: ",
          e = getCurrentException())

proc createHelpDb*(db): ResultCode {.sideEffect, raises: [], tags: [
    WriteDbEffect, ReadDbEffect, WriteIOEffect, ReadIOEffect, RootEffect],
    contractual.} =
  ## Create the table help and fill it with help entries from the configuration
  ## file
  ##
  ## * db - the connection to the shell's database
  ##
  ## Returns QuitSuccess if creation was successfull, otherwise QuitFailure and
  ## show message what wrong
  require:
    db != nil
  body:
    # Create table help in the shell's database
    try:
      db.createTables(obj = newHelpEntry())
    except DbError, CapacityError, ValueError:
      return showError(message = "Can't create 'help' table. Reason: ",
          e = getCurrentException())
    return readHelpFromFile(db = db)

proc deleteHelpEntry*(topic: UserInput; db): ResultCode {.gcsafe, sideEffect,
    raises: [], tags: [ReadDbEffect, WriteDbEffect, WriteIOEffect, RootEffect],
    contractual.} =
  ## Delete the help entry from the help table in the shell's database
  ##
  ## * topic   - the topic of the help. Used as search entry in help
  ## * db      - the connection to the shell's database
  ##
  ## Returns QuitSuccess if the help entry was successfully deleted from the database,
  ## otherwise QuitFailure and show message what wrong
  require:
    topic.len > 0
    db != nil
  body:
    try:
      if db.getValue(query = sql(query = "SELECT topic FROM help WHERE topic=?"),
          args = topic).len == 0:
        return showError(message = "Can't delete the help entry for topic '" &
            topic & "' because there is no that topic.")
      db.exec(query = sql(query = "DELETE FROM help WHERE topic=?"), args = topic)
      return QuitSuccess.ResultCode
    except DbError:
      return showError(message = "Can't delete the help entry in the database. Reason: ",
          e = getCurrentException())
