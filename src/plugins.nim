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

import std/[db_sqlite, os, osproc, parseopt, streams, strutils, tables, terminal]
import contracts
import columnamount, constants, databaseid, history, input, lstring, options,
    output, resultcode

const
  minApiVersion: float = 0.2
  ## FUNCTION
  ##
  ## The minimal version of the shell's plugins' API which plugins must support
  ## in order to work

  pluginsCommands* = ["list", "remove", "show", "add", "enable", "disable"]
  ## FUNCTION
  ##
  ## The list of available subcommands for command plugin

type
  PluginData* = object
    ## FUNCTION
    ##
    ## Store information about the shell's plugin
    path*: string ## Full path to the selected plugin
    api*: seq[string] ## The list of API calls supported by the plugin
  PluginsList* = Table[string, PluginData]
  ## FUNCTION
  ##
  ## Used to store the enabled shell's plugins

using
  db: DbConn # Connection to the shell's database
  arguments: UserInput # The string with arguments entered by the user for the command
  pluginsList: var PluginsList # The list of enabled plugins
  historyIndex: var HistoryRange # The index of the last command in the shell's history

proc createPluginsDb*(db): ResultCode {.gcsafe, sideEffect, raises: [], tags: [
    WriteDbEffect, ReadDbEffect, WriteIOEffect], locks: 0, contractual.} =
  ## FUNCTION
  ##
  ## Create the table plugins
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
    try:
      db.exec(query = sql(query = """CREATE TABLE plugins (
                 id          INTEGER       PRIMARY KEY,
                 location    VARCHAR(""" & $maxInputLength &
            """) NOT NULL,
                 enabled     BOOLEAN       NOT NULL
              )"""))
    except DbError:
      return showError(message = "Can't create 'plugins' table. Reason: ",
          e = getCurrentException())
    return QuitSuccess.ResultCode

proc execPlugin*(pluginPath: string; arguments: openArray[string]; db): tuple [
    code: ResultCode; answer: LimitedString] {.gcsafe, sideEffect, raises: [],
    tags: [ExecIOEffect, ReadEnvEffect, ReadIOEffect, WriteIOEffect,
    ReadDbEffect, TimeEffect, WriteDbEffect, RootEffect], contractual.} =
  ## FUNCTION
  ##
  ## Communicate with the selected plugin via the shell's plugins API. Run the
  ## selected plugin, send a message to it to execute the selected section of
  ## the plugin and show its output to the user.
  ##
  ## PARAMETERS
  ##
  ## * pluginPath - the full path to the plugin which will be executed
  ## * arguments  - the arguments which will be passed to the plugin
  ## * db         - the connection to the shell's database
  ##
  ## RETURNS
  ##
  ## Tuple with result code: QuitSuccess if the selected plugin was properly
  ## executed, otherwise QuitFailure and LimitedString with the plugin's
  ## answer.
  require:
    pluginPath.len() > 0
    arguments.len() > 0
    db != nil
  body:
    let
      emptyAnswer = emptyLimitedString(capacity = maxInputLength)
      plugin = try:
          startProcess(command = pluginPath, args = arguments)
        except OSError, Exception:
          return (showError(message = "Can't execute the plugin '" &
              pluginPath & "'. Reason: ", e = getCurrentException()), emptyAnswer)
    result.answer = emptyAnswer
    try:
      # Read the plugin response and act accordingly to it
      for line in plugin.lines:
        var options = initOptParser(cmdline = line.strip())
        while true:
          options.next()
          case options.key
          # Show the message sent by the plugin in the standard output
          of "showOutput":
            let remainingOptions = options.remainingArgs()
            let color = (if remainingOptions.len() ==
                1: fgDefault else: parseEnum[ForegroundColor](remainingOptions[1]))
            showOutput(message = remainingOptions[0], fgColor = color)
          # Show the message sent by the plugin in the standard error
          of "showError":
            showError(message = options.remainingArgs.join(sep = " "))
          # Set the selected shell's option. Arguments are name of the option,
          # its value, decription and type
          of "setOption":
            let remainingOptions = options.remainingArgs()
            if remainingOptions.len() < 4:
              showError(message = "Insufficient arguments for setOption.")
              break
            setOption(optionName = initLimitedString(capacity = maxNameLength,
                text = remainingOptions[0]), value = initLimitedString(
                capacity = maxInputLength, text = remainingOptions[1]),
                description = initLimitedString(capacity = maxInputLength,
                text = remainingOptions[2]), valueType = parseEnum[ValueType](
                remainingOptions[3]), db = db)
          # Remove the selected shell's option. The argument is the name of the
          # option to remove
          of "removeOption":
            let remainingOptions = options.remainingArgs()
            if remainingOptions.len() == 0:
              showError(message = "Insufficient arguments for removeOption.")
              break
            if deleteOption(optionName = initLimitedString(
                capacity = maxNameLength, text = remainingOptions[0]),
                    db = db) == QuitFailure:
              showError(message = "Failed to remove option '" &
                  remainingOptions[0] & "'.")
              break
          # Get the value of the selected shell's option. The argument is the name
          # of the option which value will be get
          of "getOption":
            let remainingOptions = options.remainingArgs()
            if remainingOptions.len() == 0:
              showError(message = "Insufficient arguments for getOption.")
              break
            plugin.inputStream.write($getOption(optionName = initLimitedString(
                capacity = maxNameLength, text = remainingOptions[0]),
                    db = db) & "\n")
            plugin.inputStream.flush()
          # Set the answer from the plugin. The argument is the plugin's answer
          # with semicolon limited values
          of "answer":
            let remainingOptions = options.remainingArgs()
            if remainingOptions.len() == 0:
              showError(message = "Insufficient arguments for answer.")
              break
            result.answer = initLimitedString(capacity = remainingOptions[
                0].len, text = remainingOptions[0])
          # Do nothing if the plugin sent any unknown request or response
          else:
            discard
          break
    except OSError, IOError, Exception:
      return (showError(message = "Can't get the plugin '" & pluginPath &
          "' output. Reason: ", e = getCurrentException()), emptyAnswer)
    if plugin.peekExitCode().ResultCode == 2:
      return (showError(message = "Plugin '" & pluginPath &
          "' doesn't support API command '" & arguments[0] & "'"), emptyAnswer)
    result.code = plugin.peekExitCode().ResultCode
    try:
      plugin.close()
    except OSError, IOError, Exception:
      return (showError(message = "Can't close process for the plugin '" &
          pluginPath & "'. Reason: ", e = getCurrentException()), emptyAnswer)

proc checkPlugin*(pluginPath: string; db): PluginData {.gcsafe, sideEffect,
    raises: [], tags: [WriteIOEffect, WriteDbEffect, TimeEffect, ExecIOEffect,
    ReadEnvEffect, ReadIOEffect, ReadDbEffect, RootEffect], contractual.} =
  ## FUNCTION
  ##
  ## Get information about the selected plugin and check it compatybility with
  ## the shell's API
  ##
  ## PARAMETERS
  ##
  ## * pluginPath - the full path to the plugin which will be checked
  ## * db         - the connection to the shell's database
  ##
  ## RETURNS
  ##
  ## PluginData object with information about the selected plugin or an empty
  ## object if the plugin isn't compatible with the shell's API
  require:
    pluginPath.len() > 0
    db != nil
  body:
    let pluginData = execPlugin(pluginPath = pluginPath, arguments = ["info"], db = db)
    if pluginData.code == QuitFailure:
      return
    let pluginInfo = split(s = $pluginData.answer, sep = ";")
    if pluginInfo.len() < 4:
      return
    try:
      if parseFloat(s = pluginInfo[2]) < minApiVersion:
        return
    except ValueError:
      return
    result = PluginData(path: pluginPath, api: split(s = pluginInfo[3], sep = ","))

proc addPlugin*(db; arguments; pluginsList): ResultCode {.gcsafe, sideEffect,
    raises: [], tags: [WriteIOEffect, ReadDirEffect, ReadDbEffect, ExecIOEffect,
    ReadEnvEffect, ReadIOEffect, TimeEffect, WriteDbEffect, RootEffect],
    contractual.} =
  ## FUNCTION
  ##
  ## Add the plugin from the selected full path to the shell and enable it.
  ##
  ## PARAMETERS
  ##
  ## * db          - the connection to the shell's database
  ## * arguments   - the arguments which the user entered to the command
  ## * pluginsList - the list of currently enabled shell's plugins
  ##
  ## RETURNS
  ##
  ## QuitSuccess if the selected plugin was properly added, otherwise
  ## QuitFailure. Also, updated parameter pluginsList
  require:
    db != nil
    arguments.len() > 0
  body:
    # Check if the user entered path to the plugin
    if arguments.len() < 5:
      return showError(message = "Please enter the path to the plugin which will be added to the shell.")
    let pluginPath: string = try:
        normalizedPath(path = getCurrentDir() & DirSep & $arguments[4..^1])
      except OSError:
        $arguments[4..^1]
    # Check if the file exists
    if not fileExists(filename = pluginPath):
      return showError(message = "File '" & pluginPath & "' doesn't exist.")
    try:
      # Check if the plugin isn't added previously
      if db.getRow(query = sql(query = "SELECT id FROM plugins WHERE location=?"),
          pluginPath) != @[""]:
        return showError(message = "File '" & pluginPath & "' is already added as a plugin to the shell.")
      # Add the plugin to the shell database and the list of enabled plugins
      let newId = db.insertID(query = sql(
          query = "INSERT INTO plugins (location, enabled) VALUES (?, 1)"), pluginPath)
      # Check if the plugin can be added
      let newPlugin = checkPlugin(pluginPath = pluginPath, db = db)
      if newPlugin.path.len() == 0:
        db.exec(query = sql(query = "DELETE FROM plugins WHERE localtion=?"), pluginPath)
        return showError(message = "Can't add file '" & pluginPath & "' as the shell's plugins because either it isn't plugin or its API is incompatible with the shell's API.")
      # Execute the installation code of the plugin
      if "install" in newPlugin.api:
        if execPlugin(pluginPath = pluginPath, arguments = ["install"],
            db = db).code != QuitSuccess:
          db.exec(query = sql(query = "DELETE FROM plugins WHERE localtion=?"), pluginPath)
          return showError(message = "Can't install plugin '" & pluginPath & "'.")
      # Execute the enabling code of the plugin
      if "enable" in newPlugin.api:
        if execPlugin(pluginPath = pluginPath, arguments = ["enable"],
            db = db).code != QuitSuccess:
          db.exec(query = sql(query = "DELETE FROM plugins WHERE localtion=?"), pluginPath)
          return showError(message = "Can't enable plugin '" & pluginPath & "'.")
      pluginsList[$newId] = newPlugin
    except DbError:
      return showError(message = "Can't add plugin to the shell. Reason: ",
          e = getCurrentException())
    showOutput(message = "File '" & pluginPath &
        "' added as a plugin to the shell.", fgColor = fgGreen);
    return QuitSuccess.ResultCode

proc initPlugins*(helpContent: var HelpTable; db): PluginsList {.gcsafe,
    sideEffect, raises: [], tags: [ExecIOEffect, ReadEnvEffect, ReadIOEffect,
    WriteIOEffect, TimeEffect, WriteDbEffect, ReadDbEffect, RootEffect],
    contractual.} =
  ## FUNCTION
  ##
  ## Initialize the shell's plugins. Set help related to the plugins, load
  ## the enabled plugins and initialize them
  ##
  ## PARAMETERS
  ##
  ## * helpContent - the HelpTable with help content of the shell
  ## * db          - the connection to the shell's database
  ##
  ## RETURNS
  ##
  ## The list of enabled plugins and the updated helpContent with the help
  ## for the commands related to the shell's plugins.
  require:
    db != nil
  ensure:
    helpContent.len() > `helpContent`.len()
  body:
    # Set the help related to the plugins
    helpContent["plugin"] = HelpEntry(usage: "plugin ?subcommand?",
        content: "If entered without subcommand, show the list of available subcommands for plugins. Otherwise, execute the selected subcommand.")
    helpContent["plugin list"] = HelpEntry(usage: "plugin list ?all?",
        content: "Show the list of all enabled plugins. If parameter all added, show all installed plugins.")
    helpContent["plugin remove"] = HelpEntry(usage: "plugin remove [index]",
        content: "Uninstall the plugin with the selected index.")
    helpContent["plugin show"] = HelpEntry(usage: "plugin show [index]",
        content: "Show details (path, status, etc) for the plugin with the selected index.")
    helpContent["plugin add"] = HelpEntry(usage: "plugin add [path]",
        content: "Install the selected plugin in the shell. Path must be absolute or relative path to the plugin.")
    helpContent["plugin enable"] = HelpEntry(usage: "plugin enable [index]",
        content: "Enable the selected plugin. Index must be the index of an installed plugin.")
    helpContent["alias disable"] = HelpEntry(usage: "alias disable [index]",
        content: "Disable the selected plugin. Index must be the index of an installed plugin.")
    # Load all enabled plugins and execute the initialization code of the plugin
    try:
      for dbResult in db.fastRows(query = sql(
          query = "SELECT id, location, enabled FROM plugins ORDER BY id ASC")):
        if dbResult[2] == "1":
          let newPlugin = checkPlugin(pluginPath = dbResult[1], db = db)
          if newPlugin.path.len() == 0:
            db.exec(query = sql(query = "UPDATE plugins SET enabled=0 WHERE id=?"),
                dbResult[0])
            showError(message = "Plugin '" & dbResult[1] & "' isn't compatible with the current version of shell's API and will be disabled.")
            continue
          if "init" in newPlugin.api:
            if execPlugin(pluginPath = dbResult[1], arguments = ["init"],
                db = db).code != QuitSuccess:
              showError(message = "Can't initialize plugin '" & dbResult[
                  1] & "'.")
              continue
          result[dbResult[0]] = newPlugin
    except DbError:
      showError(message = "Can't read data about the shell's plugins. Reason: ",
          e = getCurrentException())

proc removePlugin*(db; arguments; pluginsList: var PluginsList): ResultCode {.gcsafe,
    sideEffect, raises: [], tags: [WriteDbEffect, ReadDbEffect, ExecIOEffect,
    ReadEnvEffect, ReadIOEffect, TimeEffect, WriteIOEffect, RootEffect],
    contractual.} =
  ## FUNCTION
  ##
  ## Disable the plugin and remove it from the shell.
  ##
  ## PARAMETERS
  ##
  ## * db           - the connection to the shell's database
  ## * arguments    - the arguments which the user entered to the command
  ## * pluginsList  - the list of currently enabled shell's plugins
  ##
  ## RETURNS
  ##
  ## QuitSuccess if the selected plugin was properly added, otherwise
  ## QuitFailure. Also, updated parameter pluginsList
  require:
    db != nil
    arguments.len() > 0
  body:
    # Check if the user entered proper amount of arguments to the command
    if arguments.len() < 8:
      return showError(message = "Please enter the Id to the plugin which will be removed from the shell.")
    let
      pluginId: DatabaseId = try:
          parseInt($arguments[7 .. ^1]).DatabaseId
        except ValueError:
          return showError(message = "The Id of the plugin must be a positive number.")
      pluginPath: string = try:
          db.getValue(query = sql(query = "SELECT location FROM plugins WHERE id=?"), pluginId)
        except DbError:
          return showError(message = "Can't get plugin's Id from database. Reason: ",
            e = getCurrentException())
    try:
      if pluginPath.len() == 0:
        return showError(message = "The plugin with the Id: " & $pluginId &
          " doesn't exist.")
      # Execute the disabling code of the plugin first
      if execPlugin(pluginPath = pluginPath, arguments = ["disable"],
          db = db).code != QuitSuccess:
        return showError(message = "Can't disable plugin '" & pluginPath & "'.")
      # Execute the uninstalling code of the plugin
      if execPlugin(pluginPath = pluginPath, arguments = ["uninstall"],
          db = db).code != QuitSuccess:
        return showError(message = "Can't remove plugin '" & pluginPath & "'.")
      # Remove the plugin from the base
      db.exec(query = sql(query = "DELETE FROM plugins WHERE id=?"), pluginId)
    except DbError:
      return showError(message = "Can't delete plugin from database. Reason: ",
          e = getCurrentException())
    # Remove the plugin from the list of enabled plugins
    pluginsList.del($pluginId)
    showOutput(message = "Deleted the plugin with Id: " & $pluginId,
        fgColor = fgGreen)
    return QuitSuccess.ResultCode

proc togglePlugin*(db; arguments; pluginsList: var PluginsList;
    disable: bool = true): ResultCode {.gcsafe, sideEffect, raises: [], tags: [
    WriteIOEffect, ReadDbEffect, WriteDbEffect, ReadEnvEffect, TimeEffect,
    ReadIOEffect, ExecIOEffect, RootEffect], contractual.} =
  ## FUNCTION
  ##
  ## Enable or disable the selected plugin.
  ##
  ## PARAMETERS
  ##
  ## * db           - the connection to the shell's database
  ## * arguments    - the arguments which the user entered to the command
  ## * pluginsList  - the list of currently enabled shell's plugins
  ## * disable      - if true, disable the plugin, otherwise enable it
  ##
  ## RETURNS
  ##
  ## QuitSuccess if the selected plugin was properly enabled or disabled,
  ## otherwise QuitFailure. Also, updated parameter pluginsList
  require:
    db != nil
    arguments.len() > 0
  body:
    let
      idStart: int = (if disable: 8 else: 7)
      actionName: string = (if disable: "disable" else: "enable")
    # Check if the user entered proper amount of arguments
    if arguments.len() < (idStart + 1):
      return showError(message = "Please enter the Id to the plugin which will be " &
          actionName & ".")
    let
      pluginId: DatabaseId = try:
          parseInt($arguments[idStart .. ^1]).DatabaseId
        except ValueError:
          return showError(message = "The Id of the plugin must be a positive number.")
      pluginState: BooleanInt = (if disable: 0 else: 1)
      pluginPath: string = try:
          db.getValue(query = sql(query = "SELECT location FROM plugins WHERE id=?"), pluginId)
        except DbError:
          return showError(message = "Can't get plugin's location from database. Reason: ",
            e = getCurrentException())
    try:
      # Check if plugin exists
      if pluginPath.len() == 0:
        return showError(message = "Plugin with Id: " & $pluginId & " doesn't exists.")
      # Check if plugin can be enabled due to version of API
      let newPlugin = checkPlugin(pluginPath = pluginPath, db = db)
      if newPlugin.path.len() == 0 and not disable:
        return showError(message = "Can't enable plugin with Id: " & $pluginId & " because its API version is incompatible with the shell's version.")
      # Execute the enabling or disabling code of the plugin
      if actionName in newPlugin.api:
        if execPlugin(pluginPath = pluginPath, arguments = [actionName],
            db = db).code != QuitSuccess:
          return showError(message = "Can't " & actionName & " plugin '" &
              pluginPath & "'.")
      # Update the state of the plugin
      db.exec(query = sql(query = ("UPDATE plugins SET enabled=? WHERE id=?")),
          pluginState, pluginId)
      # Remove or add the plugin to the list of enabled plugins
      if disable:
        pluginsList.del($pluginId)
      else:
        let newPlugin = checkPlugin(pluginPath = pluginPath, db = db)
        if newPlugin.path.len() == 0:
          return QuitFailure.ResultCode
        pluginsList[$pluginId] = newPlugin
    except DbError:
      return showError(message = "Can't " & actionName & " plugin. Reason: ",
          e = getCurrentException())
    showOutput(message = (if disable: "Disabled" else: "Enabled") &
        " the plugin '" & $pluginPath & "'", fgColor = fgGreen)
    return QuitSuccess.ResultCode

proc listPlugins*(arguments; plugins: PluginsList; db): ResultCode {.gcsafe, sideEffect, raises: [], tags: [ReadIOEffect, WriteIOEffect, ReadDbEffect, WriteDbEffect, ReadEnvEffect, TimeEffect], contractual.} =
  ## FUNCTION
  ##
  ## List enabled plugins, if entered command was "plugin list all" list all
  ## installed then.
  ##
  ## PARAMETERS
  ##
  ## * arguments    - the user entered text with arguments for showing plugins
  ## * plugins      - the list of enabled plugins
  ## * db           - the connection to the shell's database
  ##
  ## RETURNS
  ##
  ## QuitSuccess if the list of plugins was properly show, otherwise
  ## QuitFailure.
  require:
    arguments.len() > 3
  body:
    let
      columnLength: ColumnAmount = try: db.getValue(query =
          sql(query = "SELECT location FROM plugins ORDER BY LENGTH(location) DESC LIMIT 1")).len().ColumnAmount
        except DbError: 10.ColumnAmount
      spacesAmount: ColumnAmount = try: terminalWidth().ColumnAmount /
          12 except ValueError: 6.ColumnAmount
    # Show the list of enabled plugins
    if arguments == "list":
      showFormHeader(message = "Enabled plugins are:")
      try:
        showOutput(message = indent(s = "ID   $1" % [alignLeft(
          s = "Path",
          count = columnLength.int)], count = spacesAmount.int),
              fgColor = fgMagenta)
      except ValueError:
        showOutput(message = indent(s = "ID   Path",
            count = spacesAmount.int), fgColor = fgMagenta)
      for id, data in plugins.pairs:
        showOutput(message = indent(s = alignLeft(id, count = 4) & " " &
            alignLeft(s = data.path, count = columnLength.int),
                count = spacesAmount.int))
    # Show the list of all installed plugins with information about their state
    elif arguments == "list all":
      showFormHeader(message = "All available plugins are:")
      try:
        showOutput(message = indent(s = "ID   $1 Enabled" % [alignLeft(
            s = "Path", count = columnLength.int)], count = spacesAmount.int),
                fgColor = fgMagenta)
      except ValueError:
        showOutput(message = indent(s = "ID   Path Enabled",
            count = spacesAmount.int), fgColor = fgMagenta)
      try:
        for row in db.fastRows(query = sql(
            query = "SELECT id, location, enabled FROM plugins")):
          showOutput(message = indent(s = alignLeft(row[0], count = 4) & " " &
              alignLeft(s = row[1], count = columnLength.int) & " " & (if row[
                  2] == "1": "Yes" else: "No"), count = spacesAmount.int))
      except DbError:
        return showError(message = "Can't read info about plugin from database. Reason:",
            e = getCurrentException())
    return QuitSuccess.ResultCode

proc showPlugin*(arguments; historyIndex; plugins: PluginsList;
    db): ResultCode {.gcsafe, sideEffect, raises: [], tags: [
    WriteIOEffect, ReadIOEffect, ReadDbEffect, WriteDbEffect, ReadEnvEffect,
    TimeEffect, ExecIOEffect, RootEffect], contractual.} =
  ## FUNCTION
  ##
  ## Show details about the selected plugin, its ID, path and status
  ##
  ## PARAMETERS
  ##
  ## * arguments    - the user entered text with arguments for the showing
  ##                  plugin
  ## * historyIndex - the index of the last command in the shell's history
  ## * plugins      - the list of enabled plugins
  ## * db           - the connection to the shell's database
  ##
  ## RETURNS
  ##
  ## QuitSuccess if the selected plugin was properly show, otherwise
  ## QuitFailure. Also, updated parameter historyIndex
  require:
    arguments.len() > 0
    db != nil
  body:
    if arguments.len() < 6:
      historyIndex = updateHistory(commandToAdd = "plugin show", db = db,
          returnCode = QuitFailure.ResultCode)
      return showError(message = "Enter the ID of the plugin to show.")
    let id: DatabaseId = try:
        parseInt(s = $arguments[5 .. ^1]).DatabaseId
      except ValueError:
        historyIndex = updateHistory(commandToAdd = "plugin show", db = db,
            returnCode = QuitFailure.ResultCode)
        return showError(message = "The Id of the plugin must be a positive number.")
    let row: Row = try:
          db.getRow(query = sql(query = "SELECT location, enabled FROM plugins WHERE id=?"), args = id)
      except DbError:
        historyIndex = updateHistory(commandToAdd = "plugin show", db = db,
            returnCode = QuitFailure.ResultCode)
        return showError(message = "Can't read plugin data from database. Reason: ",
            e = getCurrentException())
    if row[0] == "":
      historyIndex = updateHistory(commandToAdd = "plugin show", db = db,
          returnCode = QuitFailure.ResultCode)
      return showError(message = "The plugin with the ID: " & $id &
        " doesn't exists.")
    historyIndex = updateHistory(commandToAdd = "plugin show", db = db)
    let spacesAmount: ColumnAmount = try:
        terminalWidth().ColumnAmount / 12
      except ValueError:
        6.ColumnAmount
    showOutput(message = indent(s = alignLeft(s = "Id:", count = 13),
        count = spacesAmount.int), newLine = false, fgColor = fgMagenta)
    showOutput(message = $id)
    showOutput(message = indent(s = alignLeft(s = "Path:", count = 13),
        count = spacesAmount.int), newLine = false, fgColor = fgMagenta)
    showOutput(message = row[0])
    showOutput(message = indent(s = alignLeft(s = "Enabled: ", count = 13),
        count = spacesAmount.int), newLine = false, fgColor = fgMagenta)
    showOutput(message = (if row[1] == "1": "Yes" else: "No"))
    showOutput(message = indent(s = alignLeft(s = "API version: ", count = 13),
        count = spacesAmount.int), newLine = false, fgColor = fgMagenta)
    let pluginData = execPlugin(pluginPath = row[0], arguments = ["info"], db = db)
    # If plugin contains any aditional information, show them
    if pluginData.code == QuitSuccess:
      let pluginInfo = split($pluginData.answer, ";")
      if pluginInfo.len() > 2:
        showOutput(message = pluginInfo[2])
      else:
        showOutput(message = "0.1")
      showOutput(message = indent(s = alignLeft(s = "API used: ", count = 13),
          count = spacesAmount.int), newLine = false, fgColor = fgMagenta)
      showOutput(message = pluginInfo[3])
      showOutput(message = indent(s = alignLeft(s = "Name: ", count = 13),
          count = spacesAmount.int), newLine = false, fgColor = fgMagenta)
      showOutput(message = pluginInfo[0])
      if pluginInfo.len() > 1:
        showOutput(message = indent(s = "Description: ",
            count = spacesAmount.int), newLine = false, fgColor = fgMagenta)
        showOutput(message = pluginInfo[1])
    else:
      showOutput(message = "0.1")
    return QuitSuccess.ResultCode
