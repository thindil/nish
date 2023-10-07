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

## This module contains code related to the shells' plugin system, like adding,
## removing or executing the plugins. For examples of how to use the shell's
## plugins' API, please look at the testplugin.sh in the tools directory.

# Standard library imports
import std/[os, osproc, parseopt, streams, strutils, tables, terminal]
# Database library import, depends on version of Nim
when (NimMajor, NimMinor, NimPatch) >= (1, 7, 3):
  import db_connector/db_sqlite
else:
  import std/db_sqlite
# External modules imports
import ansiparse, contracts, nancy, termstyle
# Internal imports
import commandslist, constants, databaseid, help, lstring, options,
    output, resultcode

const
  minApiVersion: float = 0.2
  ## The minimal version of the shell's plugins' API which plugins must support
  ## in order to work

  pluginsCommands*: array[6, string] = ["list", "remove", "show", "add",
      "enable", "disable"]
    ## The list of available subcommands for command plugin

type
  PluginData = object
    ## Store information about the shell's plugin
    path*: string    ## Full path to the selected plugin
    api: seq[string] ## The list of API calls supported by the plugin
  PluginResult* = tuple [code: ResultCode,
      answer: LimitedString] ## Store the result of the plugin's API command

using
  db: DbConn # Connection to the shell's database
  arguments: UserInput # The string with arguments entered by the user for the command
  commands: ref CommandsList # The list of the shell's commands

proc createPluginsDb*(db): ResultCode {.gcsafe, sideEffect, raises: [], tags: [
    WriteDbEffect, ReadDbEffect, WriteIOEffect, RootEffect], contractual.} =
  ## Create the table plugins
  ##
  ## * db - the connection to the shell's database
  ##
  ## Returns QuitSuccess if creation was successfull, otherwise QuitFailure and
  ## show message what wrong
  require:
    db != nil
  body:
    try:
      db.exec(query = sql(query = """CREATE TABLE plugins (
                 id          INTEGER       PRIMARY KEY,
                 location    VARCHAR(""" & $maxInputLength &
            """) NOT NULL,
                 enabled     BOOLEAN       NOT NULL,
                 precommand  BOOLEAN       NOT NULL,
                 postcommand BOOLEAN       NOT NULL
              )"""))
    except DbError:
      return showError(message = "Can't create 'plugins' table. Reason: ",
          e = getCurrentException())
    return QuitSuccess.ResultCode

proc execPlugin*(pluginPath: string; arguments: openArray[string]; db;
    commands): PluginResult {.sideEffect, raises: [], tags: [
    ExecIOEffect, ReadEnvEffect, ReadIOEffect, WriteIOEffect, ReadDbEffect,
    TimeEffect, WriteDbEffect, RootEffect], contractual.} =
  ## Communicate with the selected plugin via the shell's plugins API. Run the
  ## selected plugin, send a message to it to execute the selected section of
  ## the plugin and show its output to the user.
  ##
  ## * pluginPath - the full path to the plugin which will be executed
  ## * arguments  - the arguments which will be passed to the plugin
  ## * db         - the connection to the shell's database
  ## * commands   - the list of the shell's commands
  ##
  ##
  ## Returns tuple with result code: QuitSuccess if the selected plugin was properly
  ## executed, otherwise QuitFailure and LimitedString with the plugin's
  ## answer.
  require:
    pluginPath.len > 0
    arguments.len > 0
    db != nil
  body:
    let
      emptyAnswer: LimitedString = emptyLimitedString(capacity = maxInputLength)
      plugin: Process = try:
          startProcess(command = pluginPath, args = arguments)
        except OSError, Exception:
          return (showError(message = "Can't execute the plugin '" &
              pluginPath & "'. Reason: ", e = getCurrentException()), emptyAnswer)

    proc showPluginOutput(options: seq[string]): bool {.closure, sideEffect,
        raises: [], tags: [WriteIOEffect, ReadIOEffect, RootEffect],
        contractual.} =
      ## Show the output from the plugin via shell's output system
      ##
      ## * options - The list of options from the API call. 0 - the text to
      ##             show, 1 - the foreground color of the text. If list
      ##             contains only one element, use default color.
      ##
      ## This procedure always returns true
      body:
        let color: ForegroundColor = try:
            if options.len == 1:
              fgDefault
            else:
              parseEnum[ForegroundColor](s = options[1])
          except ValueError:
            fgDefault
        showOutput(message = options[0], fgColor = color)
        return true

    proc showPluginError(options: seq[string]): bool {.closure, sideEffect,
        raises: [], tags: [WriteIOEffect, RootEffect], contractual.} =
      ## Show the output from the plugin via shell's output system as an
      ## error message
      ##
      ## * options - The list of options from the API call. 0 - the text to
      ##             show
      ##
      ## This procedure always returns true
      body:
        showError(message = options.join(sep = " "))
        return true

    proc setPluginOption(options: seq[string]): bool {.sideEffect, raises: [],
        tags: [WriteIOEffect, ReadDbEffect, WriteDbEffect, ReadEnvEffect,
        TimeEffect, RootEffect], contractual.} =
      ## Set the shell's option value, description or type. If the option
      ## doesn't exist, it is created.
      ##
      ## * options - The list of options from the API call. 0 - the option's name,
      ##             1 - the option's value, 2 - the option's description,
      ##             3 - the option's value type
      ##
      ## Returns true if the option was properly added or updated, otherwise false
      ## with information what happened
      body:
        if options.len < 4:
          showError(message = "Insufficient arguments for setOption.")
          return false
        try:
          setOption(optionName = initLimitedString(capacity = maxNameLength,
              text = options[0]), value = initLimitedString(
              capacity = maxInputLength, text = options[1]),
              description = initLimitedString(capacity = maxInputLength,
              text = options[2]), valueType = parseEnum[ValueType](s = options[
                  3]), db = db)
        except CapacityError, ValueError:
          showError(message = "Can't set option '" & options[0] & "'. Reason: ",
              e = getCurrentException())
          return false
        return true

    proc removePluginOption(options: seq[string]): bool {.sideEffect, raises: [
        ], tags: [WriteIOEffect, WriteDbEffect, ReadDbEffect, RootEffect],
        contractual.} =
      ## Remove the selected option from the shell
      ##
      ## * options - The list of options from the API call. 0 - the name of
      ##             the option to remove
      ##
      ## Returns true if the option was properly removed, otherwise false with
      ## information what happened
      body:
        if options.len == 0:
          showError(message = "Insufficient arguments for removeOption.")
          return false
        try:
          if deleteOption(optionName = initLimitedString(
              capacity = maxNameLength, text = options[0]), db = db) == QuitFailure:
            showError(message = "Failed to remove option '" & options[0] & "'.")
            return false
        except CapacityError:
          showError(message = "Can't remove option '" & options[0] &
              "'. Reason: ", e = getCurrentException())
          return false
        return true

    proc getPluginOption(options: seq[string]): bool {.sideEffect, raises: [],
        tags: [WriteIOEffect, ReadDbEffect, ReadEnvEffect, TimeEffect,
        RootEffect], contractual.} =
      ## Get the value of the selected option and send it to the plugin
      ##
      ## * options - The list of options from the API call. 0 - the name of
      ##             the option to get
      ##
      ## Returns true if the value of the option was properly sent to the plugin,
      ## otherwise false with information what happened
      body:
        if options.len == 0:
          showError(message = "Insufficient arguments for getOption.")
          return false
        try:
          plugin.inputStream.write(args = $getOption(
              optionName = initLimitedString(capacity = maxNameLength,
              text = options[0]), db = db) & "\n")
          plugin.inputStream.flush
        except CapacityError, IOError, OSError:
          showError(message = "Can't get the value of the selected option. Reason: ",
              e = getCurrentException())
        return true

    proc addPluginCommand(options: seq[string]): bool {.sideEffect, raises: [],
        tags: [WriteIOEffect, RootEffect], contractual.} =
      ## Add a new command to the shell
      ##
      ## * options - The list of options from the API call. 0 - the name of
      ##             the command to add
      ##
      ## Returns true if the command was properly added, otherwise false with
      ## information what happened
      body:
        if options.len == 0:
          showError(message = "Insufficient arguments for addCommand.")
          return false
        try:
          addCommand(name = initLimitedString(capacity = maxNameLength,
              text = options[0]), command = nil, commands = commands,
              plugin = pluginPath)
        except CommandsListError, CapacityError:
          showError(message = "Can't add command '" & options[0] &
              "'. Reason: " & getCurrentExceptionMsg())
          return false
        return true

    proc deletePluginCommand(options: seq[string]): bool {.sideEffect, raises: [
        ], tags: [WriteIOEffect, RootEffect], contractual.} =
      ## Remove the command from the shell
      ##
      ## * options - The list of options from the API call. 0 - the name of
      ##             the command to delete
      ##
      ## Returns true if the command was properly deleted, otherwise false with
      ## information what happened
      body:
        if options.len == 0:
          showError(message = "Insufficient arguments for deleteCommand.")
          return false
        try:
          deleteCommand(name = initLimitedString(capacity = maxNameLength,
              text = options[0]), commands = commands)
        except CommandsListError, CapacityError:
          showError(message = "Can't delete command '" & options[0] &
              "'. Reason: " & getCurrentExceptionMsg())
          return false
        return true

    proc replacePluginCommand(options: seq[string]): bool {.sideEffect,
        raises: [], tags: [WriteIOEffect, RootEffect], contractual.} =
      ## Replace the existing shell's command with the selected one
      ##
      ## * options - The list of options from the API call. 0 - the name of
      ##             the command which will be replaced
      ##
      ## Returns true if the command was properly replaced, otherwise false with
      ## information what happened
      body:
        if options.len == 0:
          showError(message = "Insufficient arguments for replaceCommand.")
          return false
        try:
          replaceCommand(name = initLimitedString(capacity = maxNameLength,
              text = options[0]), command = nil, commands = commands,
              plugin = pluginPath)
        except CommandsListError, CapacityError:
          showError(message = "Can't replace command '" & options[0] &
              "'. Reason: " & getCurrentExceptionMsg())
          return false
        return true

    proc addPluginHelp(options: seq[string]): bool {.sideEffect, raises: [],
        tags: [WriteIOEffect, ReadDbEffect, WriteDbEffect, RootEffect],
        contractual.} =
      ## Add a new help entry to the shell's help
      ##
      ## * options - The list of options from the API call. 0 - the topic of
      ##             the help entry to add, 1 - the usage section of the help
      ##             entry, 2 - the content of the help entry
      ##
      ## Returns true if the help entry was properly added, otherwise false with
      ## information what happened
      body:
        if options.len < 3:
          showError(message = "Insufficient arguments for addHelp.")
          return false
        try:
          return addHelpEntry(topic = initLimitedString(
              capacity = maxNameLength, text = options[0]),
                  usage = initLimitedString(
              capacity = maxInputLength, text = options[1]),
              plugin = initLimitedString(capacity = maxInputLength,
              text = pluginPath), content = options[2], isTemplate = false,
              db = db) == QuitFailure
        except CapacityError:
          showError(message = "Can't add help entry '" & options[0] &
              "'. Reason: ", e = getCurrentException())
          return false

    proc deletePluginHelp(options: seq[string]): bool {.sideEffect, raises: [],
        tags: [WriteIOEffect, WriteDbEffect, ReadDbEffect, RootEffect],
        contractual.} =
      ## Remove the help entry from the shell's help
      ##
      ## * options - The list of options from the API call. 0 - the name of
      ##             the help entry to delete
      ##
      ## Returns true if the help entry was properly deleted, otherwise false with
      ## information what happened
      body:
        if options.len == 0:
          showError(message = "Insufficient arguments for deleteHelp.")
          return false
        try:
          return deleteHelpEntry(topic = initLimitedString(
              capacity = maxNameLength, text = options[0]), db = db) == QuitFailure
        except CapacityError:
          showError(message = "Can't remove help entry '" & options[0] &
              "'. Reason: ", e = getCurrentException())
          return false

    proc updatePluginHelp(options: seq[string]): bool {.sideEffect, raises: [],
        tags: [WriteIOEffect, WriteDbEffect, ReadDbEffect, RootEffect],
        contractual.} =
      ## Update the existing help entry with the selected one
      ##
      ## * options - The list of options from the API call. 0 - the topic of
      ##             the help entry to replace, 1 - the new content of usage
      ##             section, 2 - the new content of the content of content
      ##             section
      ##
      ## Returns true if the help entry was properly updated, otherwise false with
      ## information what happened
      body:
        if options.len < 3:
          showError(message = "Insufficient arguments for updateHelp.")
          return false
        try:
          return updateHelpEntry(topic = initLimitedString(
              capacity = maxNameLength, text = options[0]),
              usage = initLimitedString(capacity = maxInputLength,
              text = options[
              1]), plugin = initLimitedString(capacity = maxInputLength,
              text = pluginPath), content = options[2], isTemplate = false,
              db = db) == QuitFailure
        except CapacityError:
          showError(message = "Can't update help entry '" & options[0] &
              "'. Reason: ", e = getCurrentException())
          return false

    let apiCalls: Table[string, proc(options: seq[string]): bool] = try:
          {"showOutput": showPluginOutput, "showError": showPluginError,
              "setOption": setPluginOption,
              "removeOption": removePluginOption,
              "getOption": getPluginOption,
              "addCommand": addPluginCommand,
              "deleteCommand": deletePluginCommand,
              "replaceCommand": replacePluginCommand,
              "addHelp": addPluginHelp,
              "deleteHelp": deletePluginHelp,
              "updateHelp": updatePluginHelp}.toTable
        except ValueError:
          return (showError(message = "Can't set Api calls table. Reason: ",
              e = getCurrentException()), emptyAnswer)
    result.answer = emptyAnswer
    try:
      # Read the plugin response and act accordingly to it
      for line in plugin.lines:
        var options: OptParser = initOptParser(cmdline = line.strip)
        while true:
          options.next
          # If the plugin sent a valid request, execute it
          if apiCalls.hasKey(key = options.key):
            if not apiCalls[options.key](options = options.remainingArgs):
              break
          # Set the answer from the plugin. The argument is the plugin's answer
          # with semicolon limited values
          elif options.key == "answer":
            let remainingOptions: seq[string] = options.remainingArgs
            if remainingOptions.len == 0:
              showError(message = "Insufficient arguments for answer.")
              break
            result.answer = initLimitedString(capacity = remainingOptions[
                0].len, text = remainingOptions[0])
          # The plugin sent any unknown request or response, show error about it
          else:
            showError(message = "Unknown request or response from the plugin '" &
                pluginPath & "'. Got: '" & options.key & "'")
          break
    except OSError, IOError, Exception:
      return (showError(message = "Can't get the plugin '" & pluginPath &
          "' output. Reason: ", e = getCurrentException()), emptyAnswer)
    try:
      if plugin.peekExitCode.ResultCode == 2:
        return (showError(message = "Plugin '" & pluginPath &
            "' doesn't support API command '" & arguments[0] & "'"), emptyAnswer)
      result.code = plugin.peekExitCode.ResultCode
    except OSError:
      return (showError(message = "Can't get exit code from plugin '" &
          pluginPath & "'. Reason: ", e = getCurrentException()), emptyAnswer)
    try:
      plugin.close
    except OSError, IOError, Exception:
      return (showError(message = "Can't close process for the plugin '" &
          pluginPath & "'. Reason: ", e = getCurrentException()), emptyAnswer)

proc checkPlugin*(pluginPath: string; db; commands): PluginData {.sideEffect,
    raises: [], tags: [WriteIOEffect, WriteDbEffect, TimeEffect, ExecIOEffect,
    ReadEnvEffect, ReadIOEffect, ReadDbEffect, RootEffect], contractual.} =
  ## Get information about the selected plugin and check it compatybility with
  ## the shell's API
  ##
  ## * pluginPath - the full path to the plugin which will be checked
  ## * db         - the connection to the shell's database
  ## * commands   - the list of the shell's commands
  ##
  ## Returns PluginData object with information about the selected plugin or an empty
  ## object if the plugin isn't compatible with the shell's API
  require:
    pluginPath.len > 0
    db != nil
  body:
    let pluginData: PluginResult = execPlugin(pluginPath = pluginPath, arguments = ["info"],
        db = db, commands = commands)
    if pluginData.code == QuitFailure:
      return
    let pluginInfo: seq[string] = split(s = $pluginData.answer, sep = ";")
    if pluginInfo.len < 4:
      return
    try:
      if parseFloat(s = pluginInfo[2]) < minApiVersion:
        return
    except ValueError:
      return
    result = PluginData(path: pluginPath, api: split(s = pluginInfo[3], sep = ","))

proc addPlugin*(db; arguments; commands): ResultCode {.sideEffect,
    raises: [], tags: [WriteIOEffect, ReadDirEffect, ReadDbEffect, ExecIOEffect,
    ReadEnvEffect, ReadIOEffect, TimeEffect, WriteDbEffect, RootEffect],
    contractual.} =
  ## Add the plugin from the selected full path to the shell and enable it.
  ##
  ## * db          - the connection to the shell's database
  ## * arguments   - the arguments which the user entered to the command
  ## * commands    - the list of the shell's commands
  ##
  ## Returns QuitSuccess if the selected plugin was properly added, otherwise
  ## QuitFailure. Also, updated parameter pluginsList
  require:
    db != nil
    arguments.len > 0
  body:
    # Check if the user entered path to the plugin
    if arguments.len < 5:
      return showError(message = "Please enter the path to the plugin which will be added to the shell.")
    let pluginPath: string = try:
        normalizedPath(path = getCurrentDirectory() & DirSep & $arguments[4..^1])
      except OSError:
        $arguments[4..^1]
    # Check if the file exists
    if not fileExists(filename = pluginPath):
      return showError(message = "File '" & pluginPath & "' doesn't exist.")
    try:
      # Check if the plugin isn't added previously
      if db.getRow(query = sql(query = "SELECT id FROM plugins WHERE location=?"),
          args = pluginPath) != @[""]:
        return showError(message = "File '" & pluginPath & "' is already added as a plugin to the shell.")
      # Check if the plugin can be added
      let newPlugin: PluginData = checkPlugin(pluginPath = pluginPath, db = db,
          commands = commands)
      if newPlugin.path.len == 0:
        return showError(message = "Can't add file '" & pluginPath & "' as the shell's plugins because either it isn't plugin or its API is incompatible with the shell's API.")
      # Add the plugin to the shell database
      db.exec(query = sql(query = "INSERT INTO plugins (location, enabled, precommand, postcommand) VALUES (?, 1, ?, ?)"),
          args = [pluginPath, $(if "preCommand" in newPlugin.api: 1 else: 0), $(
          if "postCommand" in newPlugin.api: 1 else: 0)])
      # Execute the installation code of the plugin
      if "install" in newPlugin.api:
        if execPlugin(pluginPath = pluginPath, arguments = ["install"],
            db = db, commands = commands).code != QuitSuccess:
          db.exec(query = sql(query = "DELETE FROM plugins WHERE location=?"),
              args = pluginPath)
          return showError(message = "Can't install plugin '" & pluginPath & "'.")
      # Execute the enabling code of the plugin
      if "enable" in newPlugin.api:
        if execPlugin(pluginPath = pluginPath, arguments = ["enable"],
            db = db, commands = commands).code != QuitSuccess:
          db.exec(query = sql(query = "DELETE FROM plugins WHERE location=?"),
              args = pluginPath)
          return showError(message = "Can't enable plugin '" & pluginPath & "'.")
    except DbError:
      return showError(message = "Can't add plugin to the shell. Reason: ",
          e = getCurrentException())
    showOutput(message = "File '" & pluginPath &
        "' added as a plugin to the shell.", fgColor = fgGreen);
    return QuitSuccess.ResultCode

proc removePlugin*(db; arguments; commands): ResultCode {.sideEffect,
    raises: [], tags: [WriteDbEffect, ReadDbEffect, ExecIOEffect, ReadEnvEffect,
    ReadIOEffect, TimeEffect, WriteIOEffect, RootEffect], contractual.} =
  ## Disable the plugin and remove it from the shell.
  ##
  ## * db        - the connection to the shell's database
  ## * arguments - the arguments which the user entered to the command
  ## * commands  - the list of the shell's commands
  ##
  ## Returns QuitSuccess if the selected plugin was properly added, otherwise
  ## QuitFailure. Also, updated parameter pluginsList
  require:
    db != nil
    arguments.len > 0
  body:
    # Check if the user entered proper amount of arguments to the command
    if arguments.len < 8:
      return showError(message = "Please enter the Id to the plugin which will be removed from the shell.")
    let
      pluginId: DatabaseId = try:
          ($arguments[7 .. ^1]).parseInt.DatabaseId
        except ValueError:
          return showError(message = "The Id of the plugin must be a positive number.")
      pluginPath: string = try:
          db.getValue(query = sql(query = "SELECT location FROM plugins WHERE id=?"),
              args = pluginId)
        except DbError:
          return showError(message = "Can't get plugin's Id from database. Reason: ",
            e = getCurrentException())
    try:
      if pluginPath.len == 0:
        return showError(message = "The plugin with the Id: " & $pluginId &
          " doesn't exist.")
      # Execute the disabling code of the plugin first
      if execPlugin(pluginPath = pluginPath, arguments = ["disable"],
          db = db, commands = commands).code != QuitSuccess:
        return showError(message = "Can't disable plugin '" & pluginPath & "'.")
      # Execute the uninstalling code of the plugin
      if execPlugin(pluginPath = pluginPath, arguments = ["uninstall"],
          db = db, commands = commands).code != QuitSuccess:
        return showError(message = "Can't remove plugin '" & pluginPath & "'.")
      # Remove the plugin from the base
      db.exec(query = sql(query = "DELETE FROM plugins WHERE id=?"),
          args = pluginId)
    except DbError:
      return showError(message = "Can't delete plugin from database. Reason: ",
          e = getCurrentException())
    # Remove the plugin from the list of enabled plugins
    showOutput(message = "Deleted the plugin with Id: " & $pluginId,
        fgColor = fgGreen)
    return QuitSuccess.ResultCode

proc togglePlugin*(db; arguments; disable: bool = true;
    commands): ResultCode {.sideEffect, raises: [], tags: [
    WriteIOEffect, ReadDbEffect, WriteDbEffect, ReadEnvEffect, TimeEffect,
    ReadIOEffect, ExecIOEffect, RootEffect], contractual.} =
  ## Enable or disable the selected plugin.
  ##
  ## * db        - the connection to the shell's database
  ## * arguments - the arguments which the user entered to the command
  ## * disable   - if true, disable the plugin, otherwise enable it
  ## * commands  - the list of the shell's commands
  ##
  ## Returns QuitSuccess if the selected plugin was properly enabled or disabled,
  ## otherwise QuitFailure. Also, updated parameter pluginsList
  require:
    db != nil
    arguments.len > 0
  body:
    let
      idStart: int = (if disable: 8 else: 7)
      actionName: string = (if disable: "disable" else: "enable")
    # Check if the user entered proper amount of arguments
    if arguments.len < (idStart + 1):
      return showError(message = "Please enter the Id to the plugin which will be " &
          actionName & ".")
    let
      pluginId: DatabaseId = try:
          ($arguments[idStart .. ^1]).parseInt.DatabaseId
        except ValueError:
          return showError(message = "The Id of the plugin must be a positive number.")
      pluginState: BooleanInt = (if disable: 0 else: 1)
      pluginPath: string = try:
          db.getValue(query = sql(query = "SELECT location FROM plugins WHERE id=?"),
              args = pluginId)
        except DbError:
          return showError(message = "Can't get plugin's location from database. Reason: ",
            e = getCurrentException())
    try:
      # Check if plugin exists
      if pluginPath.len == 0:
        return showError(message = "Plugin with Id: " & $pluginId & " doesn't exists.")
      # Check if plugin can be enabled due to version of API
      let newPlugin: PluginData = checkPlugin(pluginPath = pluginPath, db = db,
          commands = commands)
      if newPlugin.path.len == 0 and not disable:
        return showError(message = "Can't enable plugin with Id: " & $pluginId & " because its API version is incompatible with the shell's version.")
      # Execute the enabling or disabling code of the plugin
      if actionName in newPlugin.api:
        if execPlugin(pluginPath = pluginPath, arguments = [actionName],
            db = db, commands = commands).code != QuitSuccess:
          return showError(message = "Can't " & actionName & " plugin '" &
              pluginPath & "'.")
      # Update the state of the plugin
      db.exec(query = sql(query = ("UPDATE plugins SET enabled=? WHERE id=?")),
          args = [$pluginState, $pluginId])
      # Remove or add the plugin to the list of enabled plugins and clear
      # the plugin help when disabling it
      if disable:
        db.exec(query = sql(query = ("DELETE FROM help WHERE plugin=?")),
            args = pluginPath)
      elif checkPlugin(pluginPath = pluginPath, db = db, commands = commands).path.len == 0:
        return QuitFailure.ResultCode
    except DbError:
      return showError(message = "Can't " & actionName & " plugin. Reason: ",
          e = getCurrentException())
    showOutput(message = (if disable: "Disabled" else: "Enabled") &
        " the plugin '" & $pluginPath & "'", fgColor = fgGreen)
    return QuitSuccess.ResultCode

proc listPlugins*(arguments; db): ResultCode {.sideEffect, raises: [],
    tags: [ReadIOEffect, WriteIOEffect, ReadDbEffect, WriteDbEffect,
    ReadEnvEffect, TimeEffect, RootEffect], contractual.} =
  ## List enabled plugins, if entered command was "plugin list all" list all
  ## installed then.
  ##
  ## * arguments - the user entered text with arguments for showing plugins
  ## * db        - the connection to the shell's database
  ##
  ## Returns QuitSuccess if the list of plugins was properly show, otherwise
  ## QuitFailure.
  require:
    arguments.len > 3
    db != nil
  body:
    var table: TerminalTable = TerminalTable()
    # Show the list of all installed plugins with information about their state
    if arguments == "list all":
      try:
        table.add(parts = [magenta(ss = "ID"), magenta(ss = "Path"), magenta(
            ss = "Enabled")])
      except UnknownEscapeError, InsufficientInputError, FinalByteError:
        return showError(message = "Can't show all plugins list. Reason: ",
            e = getCurrentException())
      try:
        for row in db.fastRows(query = sql(
            query = "SELECT id, location, enabled FROM plugins")):
          table.add(parts = [row[0], row[1], (if row[2] ==
              "1": "Yes" else: "No")])
      except DbError, UnknownEscapeError, InsufficientInputError, FinalByteError:
        return showError(message = "Can't read info about plugin from database. Reason:",
            e = getCurrentException())
      var width: int = 0
      for size in table.getColumnSizes(maxSize = int.high):
        width = width + size
      showFormHeader(message = "All available plugins are:",
          width = width.ColumnAmount, db = db)
    # Show the list of enabled plugins
    elif arguments[0..3] == "list":
      try:
        table.add(parts = [magenta(ss = "ID"), magenta(ss = "Path")])
      except UnknownEscapeError, InsufficientInputError, FinalByteError:
        return showError(message = "Can't show plugins list. Reason: ",
            e = getCurrentException())
      try:
        for plugin in db.fastRows(query = sql(
            query = "SELECT id, location FROM plugins WHERE enabled=1")):
          table.add(parts = plugin)
      except DbError, UnknownEscapeError, InsufficientInputError, FinalByteError:
        return showError(message = "Can't show the list of enabled plugins. Reason: ",
            e = getCurrentException())
      var width: int = 0
      for size in table.getColumnSizes(maxSize = int.high):
        width = width + size
      showFormHeader(message = "Enabled plugins are:",
          width = width.ColumnAmount, db = db)
    try:
      table.echoTable
    except IOError, Exception:
      return showError(message = "Can't show the list of plugins. Reason: ",
          e = getCurrentException())
    return QuitSuccess.ResultCode

proc showPlugin*(arguments; db; commands): ResultCode {.sideEffect, raises: [],
    tags: [WriteIOEffect, ReadIOEffect, ReadDbEffect, WriteDbEffect,
    ReadEnvEffect, TimeEffect, ExecIOEffect, RootEffect, RootEffect],
    contractual.} =
  ## Show details about the selected plugin, its ID, path and status
  ##
  ## * arguments - the user entered text with arguments for the showing
  ##               plugin
  ## * plugins   - the list of enabled plugins
  ## * db        - the connection to the shell's database
  ## * commands  - the list of the shell's commands
  ##
  ## Returns QuitSuccess if the selected plugin was properly show, otherwise
  ## QuitFailure.
  require:
    arguments.len > 0
    db != nil
  body:
    if arguments.len < 6:
      return showError(message = "Enter the ID of the plugin to show.")
    let id: DatabaseId = try:
        parseInt(s = $arguments[5 .. ^1]).DatabaseId
      except ValueError:
        return showError(message = "The Id of the plugin must be a positive number.")
    let row: Row = try:
          db.getRow(query = sql(query = "SELECT location, enabled FROM plugins WHERE id=?"), args = id)
      except DbError:
        return showError(message = "Can't read plugin data from database. Reason: ",
            e = getCurrentException())
    if row[0] == "":
      return showError(message = "The plugin with the ID: " & $id &
        " doesn't exists.")
    var table: TerminalTable = TerminalTable()
    try:
      table.add(parts = [magenta(ss = "Id:"), $id])
      table.add(parts = [magenta(ss = "Path"), row[0]])
      table.add(parts = [magenta(ss = "Enabled:"), (if row[1] ==
          "1": "Yes" else: "No")])
    except UnknownEscapeError, InsufficientInputError, FinalByteError:
      return showError(message = "Can't plugin's info. Reason: ",
          e = getCurrentException())
    let pluginData: PluginResult = execPlugin(pluginPath = row[0], arguments = ["info"],
        db = db, commands = commands)
    # If plugin contains any aditional information, show them
    try:
      if pluginData.code == QuitSuccess:
        let pluginInfo: seq[string] = ($pluginData.answer).split(sep = ";")
        table.add(parts = [magenta(ss = "API version:"), (if pluginInfo.len >
            2: pluginInfo[2] else: "0.1")])
        if pluginInfo.len > 2:
          table.add(parts = [magenta(ss = "API used:"), pluginInfo[3]])
        table.add(parts = [magenta(ss = "Name:"), pluginInfo[0]])
        if pluginInfo.len > 1:
          table.add(parts = [magenta(ss = "Descrition:"), pluginInfo[1]])
      else:
        table.add(parts = [magenta(ss = "API version:"), "0.1"])
    except UnknownEscapeError, InsufficientInputError, FinalByteError:
      return showError(message = "Can't plugin's info. Reason: ",
          e = getCurrentException())
    try:
      table.echoTable
    except IOError, Exception:
      return showError(message = "Can't show plugin info. Reason: ",
          e = getCurrentException())
    return QuitSuccess.ResultCode

proc initPlugins*(db; commands) {.sideEffect, raises: [], tags: [
    ExecIOEffect, ReadEnvEffect, ReadIOEffect, WriteIOEffect, TimeEffect,
    WriteDbEffect, ReadDbEffect, RootEffect], contractual.} =
  ## Initialize the shell's plugins. Load the enabled plugins, initialize them
  ## and add the shell's commands related to the plugins' system
  ##
  ## * db          - the connection to the shell's database
  ## * pluginsList - the list of enabled plugins
  ## * commands    - the list of the shell's commands
  ##
  ## Returns The updated list of enabled plugins and the updated list of the
  ## shell's commands.
  require:
    db != nil
  body:
    # Add commands related to the shell's aliases
    proc pluginCommand(arguments: UserInput; db: DbConn;
        list: CommandLists): ResultCode {.raises: [], tags: [ReadDirEffect,
        WriteIOEffect, WriteDbEffect, ExecIOEffect, TimeEffect, ReadDbEffect,
        ReadIOEffect, ReadEnvEffect, RootEffect], contractual.} =
      ## The code of the shell's command "plugin" and its subcommands
      ##
      ## * arguments - the arguments entered by the user for the command
      ## * db        - the connection to the shell's database
      ## * list      - the additional data for the command, like id of plugin, etc
      ##
      ## Returns QuitSuccess if the selected command was successfully executed,
      ## otherwise QuitFailure.
      body:
        # No subcommand entered, show available options
        if arguments.len == 0:
          return showHelpList(command = "plugin", subcommands = pluginsCommands)
        # Add a new plugin
        if arguments.startsWith(prefix = "add"):
          return addPlugin(arguments = arguments, db = db,
              commands = list.commands)
        # Delete the selected plugin
        if arguments.startsWith(prefix = "remove"):
          return removePlugin(arguments = arguments, db = db,
              commands = list.commands)
        # Disable the selected plugin
        if arguments.startsWith(prefix = "disable"):
          return togglePlugin(arguments = arguments, db = db,
              commands = list.commands)
        # Enable the selected plugin
        if arguments.startsWith(prefix = "enable"):
          return togglePlugin(arguments = arguments, db = db, disable = false,
              commands = list.commands)
        # Show the list of available plugins
        if arguments.startsWith(prefix = "list"):
          return listPlugins(arguments = arguments, db = db)
        # Show the selected plugin
        if arguments.startsWith(prefix = "show"):
          return showPlugin(arguments = arguments, db = db,
              commands = list.commands)
        try:
          return showUnknownHelp(subCommand = arguments,
              command = initLimitedString(capacity = 6, text = "plugin"),
              helpType = initLimitedString(capacity = 6, text = "plugin"))
        except CapacityError:
          return QuitFailure.ResultCode
    try:
      addCommand(name = initLimitedString(capacity = 6, text = "plugin"),
          command = pluginCommand, commands = commands)
    except CapacityError, CommandsListError:
      showError(message = "Can't add commands related to the shell's plugins. Reason: ",
          e = getCurrentException())
    # Load all enabled plugins and execute the initialization code of the plugin
    try:
      for dbResult in db.fastRows(query = sql(
          query = "SELECT id, location, enabled FROM plugins ORDER BY id ASC")):
        if dbResult[2] == "1":
          let newPlugin: PluginData = checkPlugin(pluginPath = dbResult[1], db = db,
              commands = commands)
          if newPlugin.path.len == 0:
            db.exec(query = sql(query = "UPDATE plugins SET enabled=0 WHERE id=?"),
                args = dbResult[0])
            showError(message = "Plugin '" & dbResult[1] & "' isn't compatible with the current version of shell's API and will be disabled.")
            continue
          if "init" in newPlugin.api:
            if execPlugin(pluginPath = dbResult[1], arguments = ["init"],
                db = db, commands = commands).code != QuitSuccess:
              showError(message = "Can't initialize plugin '" & dbResult[
                  1] & "'.")
              continue
    except DbError:
      showError(message = "Can't read data about the shell's plugins. Reason: ",
          e = getCurrentException())

proc updatePluginsDb*(db): ResultCode {.gcsafe, sideEffect, raises: [], tags: [
    WriteDbEffect, ReadDbEffect, WriteIOEffect, RootEffect], contractual.} =
  ## Update the table plugins to the new version if needed
  ##
  ## * db - the connection to the shell's database
  ##
  ## Returns QuitSuccess if update was successfull, otherwise QuitFailure and
  ## show message what wrong
  require:
    db != nil
  body:
    try:
      db.exec(query = sql(query = """ALTER TABLE plugins ADD precommand BOOLEAN NOT NULL DEFAULT 0"""))
      db.exec(query = sql(query = """ALTER TABLE plugins ADD postcommand BOOLEAN NOT NULL DEFAULT 0"""))
    except DbError:
      return showError(message = "Can't update table for the shell's aliases. Reason: ",
          e = getCurrentException())
    return QuitSuccess.ResultCode

