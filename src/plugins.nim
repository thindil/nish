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

## This module contains code related to the shells' plugin system, like adding,
## removing or executing the plugins. For examples of how to use the shell's
## plugins' API, please look at the testplugin.sh in the tools directory.

# Standard library imports
import std/[os, osproc, parseopt, paths, streams, strutils, tables]
# External modules imports
import ansiparse, contracts, nancy, nimalyzer, termstyle
import norm/[model, sqlite]
# Internal imports
import commandslist, constants, help, input, options, output, theme, types

const
  minApiVersion: float = 0.2
  ## The minimal version of the shell's plugins' API which plugins must support
  ## in order to work

  pluginsCommands: seq[string] = @["list", "remove", "show", "add",
      "enable", "disable"]
    ## The list of available subcommands for command plugin

type
  PluginData = object
    ## Store information about the shell's plugin
    path: Path       ## Full path to the selected plugin
    api: seq[string] ## The list of API calls supported by the plugin
  PluginResult* = tuple [code: ResultCode,
      answer: string] ## Store the result of the plugin's API command

using
  db: DbConn # Connection to the shell's database
  arguments: UserInput # The string with arguments entered by the user for the command
  commands: ref CommandsList # The list of the shell's commands

proc newPlugin*(path: Path = "".Path; enabled: bool = false;
    preCommand: bool = false; postCommand: bool = false): Plugin {.raises: [],
    tags: [], contractual.} =
  ## Create a new data structure for the shell's plugin.
  ##
  ## * path        - the full path to the plugin
  ## * enabled     - if true, the plugin is enabled
  ## * preCommand  - if true, the plugin is executed before the user's command
  ## * postCommand - fi true, the plugin is executed after the user's command
  ##
  ## Returns the new data structure for the selected shell's plugin.
  body:
    Plugin(location: path, enabled: enabled, preCommand: preCommand,
        postCommand: postCommand)

proc createPluginsDb*(db): ResultCode {.sideEffect, raises: [], tags: [
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
      db.createTables(obj = newPlugin())
    except:
      return showError(message = "Can't create 'plugins' table. Reason: ",
          e = getCurrentException(), db = db)
    return QuitSuccess.ResultCode

proc execPlugin*(pluginPath: Path; arguments: openArray[string]; db;
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
    const emptyAnswer: string = ""
    let plugin: Process = try:
          startProcess(command = $pluginPath, args = arguments)
        except OSError, Exception:
          return (showError(message = "Can't execute the plugin '" &
              $pluginPath & "'. Reason: ", e = getCurrentException(), db = db), emptyAnswer)

    proc showPluginOutput(options: seq[string]): bool {.closure, sideEffect,
        raises: [], tags: [WriteIOEffect, ReadIOEffect, RootEffect],
        contractual, gcsafe.} =
      ## Show the output from the plugin via shell's output system
      ##
      ## * options - The list of options from the API call. 0 - the text to
      ##             show, 1 - the foreground color of the text. If list
      ##             contains only one element, use default color.
      ##
      ## This procedure always returns true
      body:
        let color: ThemeColor = try:
            if options.len == 1:
              default
            else:
              parseEnum[ThemeColor](s = options[1])
          except ValueError:
            default
        {.cast(gcsafe).}:
          showOutput(message = options[0], color = color, db = db)
        return true

    proc showPluginError(options: seq[string]): bool {.closure, sideEffect,
        raises: [], tags: [WriteIOEffect, RootEffect], contractual, gcsafe.} =
      ## Show the output from the plugin via shell's output system as an
      ## error message
      ##
      ## * options - The list of options from the API call. 0 - the text to
      ##             show
      ##
      ## This procedure always returns true
      body:
        {.cast(gcsafe).}:
          discard showError(message = options.join(sep = " "), db = db)
        return true

    proc setPluginOption(options: seq[string]): bool {.sideEffect, raises: [],
        tags: [WriteIOEffect, ReadDbEffect, WriteDbEffect, ReadEnvEffect,
        TimeEffect, RootEffect], contractual, gcsafe.} =
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
        {.cast(gcsafe).}:
          if options.len < 4:
            showError(message = "Insufficient arguments for setOption.", db = db)
            return false
          try:
            setOption(optionName = options[0], value = options[1],
                description = options[2], valueType = parseEnum[OptionValType](
                s = options[3]), db = db)
          except ValueError:
            showError(message = "Can't set option '" & options[0] &
                "'. Reason: ", e = getCurrentException(), db = db)
            return false
          return true

    proc removePluginOption(options: seq[string]): bool {.sideEffect, raises: [
        ], tags: [WriteIOEffect, WriteDbEffect, ReadDbEffect, RootEffect],
        contractual, gcsafe.} =
      ## Remove the selected option from the shell
      ##
      ## * options - The list of options from the API call. 0 - the name of
      ##             the option to remove
      ##
      ## Returns true if the option was properly removed, otherwise false with
      ## information what happened
      body:
        {.cast(gcsafe).}:
          if options.len == 0:
            showError(message = "Insufficient arguments for removeOption.", db = db)
            return false
          if deleteOption(optionName = options[0], db = db) == QuitFailure:
            showError(message = "Failed to remove option '" & options[0] &
                "'.", db = db)
            return false
          return true

    proc getPluginOption(options: seq[string]): bool {.sideEffect, raises: [],
        tags: [WriteIOEffect, ReadDbEffect, ReadEnvEffect, TimeEffect,
        RootEffect], contractual, gcsafe.} =
      ## Get the value of the selected option and send it to the plugin
      ##
      ## * options - The list of options from the API call. 0 - the name of
      ##             the option to get
      ##
      ## Returns true if the value of the option was properly sent to the plugin,
      ## otherwise false with information what happened
      body:
        {.cast(gcsafe).}:
          if options.len == 0:
            showError(message = "Insufficient arguments for getOption.", db = db)
            return false
          try:
            plugin.inputStream.write(args = $getOption(
                optionName = options[0], db = db) & "\n")
            plugin.inputStream.flush
          except IOError, OSError:
            showError(message = "Can't get the value of the selected option. Reason: ",
                e = getCurrentException(), db = db)
          return true

    proc addPluginCommand(options: seq[string]): bool {.sideEffect, raises: [],
        tags: [WriteIOEffect, RootEffect], contractual, gcsafe.} =
      ## Add a new command to the shell
      ##
      ## * options - The list of options from the API call. 0 - the name of
      ##             the command to add, any next value - the name of the
      ##             subcommand for the command
      ##
      ## Returns true if the command was properly added, otherwise false with
      ## information what happened
      body:
        {.cast(gcsafe).}:
          if options.len == 0:
            showError(message = "Insufficient arguments for addCommand.", db = db)
            return false
          try:
            if options.len > 1:
              addCommand(name = options[0], command = nil, commands = commands,
                  plugin = $pluginPath, subCommands = options[1 .. ^1])
            else:
              addCommand(name = options[0], command = nil, commands = commands,
                  plugin = $pluginPath)
          except CommandsListError:
            showError(message = "Can't add command '" & options[0] &
                "'. Reason: " & getCurrentExceptionMsg(), db = db)
            return false
          return true

    proc deletePluginCommand(options: seq[string]): bool {.sideEffect, raises: [
        ], tags: [WriteIOEffect, RootEffect], contractual, gcsafe.} =
      ## Remove the command from the shell
      ##
      ## * options - The list of options from the API call. 0 - the name of
      ##             the command to delete
      ##
      ## Returns true if the command was properly deleted, otherwise false with
      ## information what happened
      body:
        {.cast(gcsafe).}:
          if options.len == 0:
            showError(message = "Insufficient arguments for deleteCommand.", db = db)
            return false
          try:
            deleteCommand(name = options[0], commands = commands)
          except CommandsListError:
            showError(message = "Can't delete command '" & options[0] &
                "'. Reason: " & getCurrentExceptionMsg(), db = db)
            return false
          return true

    proc replacePluginCommand(options: seq[string]): bool {.sideEffect,
        raises: [], tags: [WriteIOEffect, RootEffect], contractual, gcsafe.} =
      ## Replace the existing shell's command with the selected one
      ##
      ## * options - The list of options from the API call. 0 - the name of
      ##             the command which will be replaced
      ##
      ## Returns true if the command was properly replaced, otherwise false with
      ## information what happened
      body:
        {.cast(gcsafe).}:
          if options.len == 0:
            showError(message = "Insufficient arguments for replaceCommand.", db = db)
            return false
          try:
            replaceCommand(name = options[0], command = nil,
                commands = commands, plugin = $pluginPath, db = db)
          except CommandsListError:
            showError(message = "Can't replace command '" & options[0] &
                "'. Reason: " & getCurrentExceptionMsg(), db = db)
            return false
          return true

    proc addPluginHelp(options: seq[string]): bool {.sideEffect, raises: [],
        tags: [WriteIOEffect, ReadDbEffect, WriteDbEffect, RootEffect],
        contractual, gcsafe.} =
      ## Add a new help entry to the shell's help
      ##
      ## * options - The list of options from the API call. 0 - the topic of
      ##             the help entry to add, 1 - the usage section of the help
      ##             entry, 2 - the content of the help entry
      ##
      ## Returns true if the help entry was properly added, otherwise false with
      ## information what happened
      body:
        {.cast(gcsafe).}:
          if options.len < 3:
            showError(message = "Insufficient arguments for addHelp.", db = db)
            return false
          return addHelpEntry(topic = options[0], usage = options[1],
              plugin = $pluginPath, content = options[2], isTemplate = false,
              db = db) == QuitFailure

    proc deletePluginHelp(options: seq[string]): bool {.sideEffect, raises: [],
        tags: [WriteIOEffect, WriteDbEffect, ReadDbEffect, RootEffect],
        contractual, gcsafe.} =
      ## Remove the help entry from the shell's help
      ##
      ## * options - The list of options from the API call. 0 - the name of
      ##             the help entry to delete
      ##
      ## Returns true if the help entry was properly deleted, otherwise false with
      ## information what happened
      body:
        {.cast(gcsafe).}:
          if options.len == 0:
            showError(message = "Insufficient arguments for deleteHelp.", db = db)
            return false
          return deleteHelpEntry(topic = options[0], db = db) == QuitFailure

    proc updatePluginHelp(options: seq[string]): bool {.sideEffect, raises: [],
        tags: [WriteIOEffect, WriteDbEffect, ReadDbEffect, RootEffect],
        contractual, gcsafe.} =
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
        {.cast(gcsafe).}:
          if options.len < 3:
            showError(message = "Insufficient arguments for updateHelp.", db = db)
            return false
          return updateHelpEntry(topic = options[0], usage = options[1],
              plugin = $pluginPath, content = options[2], isTemplate = false,
              db = db) == QuitFailure

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
              e = getCurrentException(), db = db), emptyAnswer)
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
              showError(message = "Insufficient arguments for answer.", db = db)
              break
            result.answer = remainingOptions[0]
          # The plugin sent any unknown request or response, show error about it
          else:
            showError(message = "Unknown request or response from the plugin '" &
                $pluginPath & "'. Got: '" & options.key & "'", db = db)
          break
    except OSError, IOError, Exception:
      return (showError(message = "Can't get the plugin '" & $pluginPath &
          "' output. Reason: ", e = getCurrentException(), db = db), emptyAnswer)
    try:
      if plugin.peekExitCode.ResultCode == 2:
        return (showError(message = "Plugin '" & $pluginPath &
            "' doesn't support API command '" & arguments[0] & "'", db = db), emptyAnswer)
      result.code = plugin.peekExitCode.ResultCode
    except OSError:
      return (showError(message = "Can't get exit code from plugin '" &
          $pluginPath & "'. Reason: ", e = getCurrentException(), db = db), emptyAnswer)
    try:
      plugin.close
    except OSError, IOError, Exception:
      return (showError(message = "Can't close process for the plugin '" &
          $pluginPath & "'. Reason: ", e = getCurrentException(), db = db), emptyAnswer)

proc checkPlugin(pluginPath: Path; db; commands): PluginData {.sideEffect,
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
    let pluginData: PluginResult = execPlugin(pluginPath = pluginPath,
        arguments = ["info"], db = db, commands = commands)
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

proc addPlugin(db; arguments; commands): ResultCode {.sideEffect,
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
      return showError(message = "Please enter the path to the plugin which will be added to the shell.", db = db)
    var pluginPath: Path = getCurrentDirectory() / arguments[4 .. ^1].Path
    normalizePath(path = pluginPath)
    # Check if the file exists
    if not fileExists(filename = $pluginPath):
      return showError(message = "File '" & $pluginPath & "' doesn't exist.", db = db)
    try:
      # Check if the plugin isn't added previously
      if db.exists(T = Plugin, cond = "location=?", params = pluginPath):
        return showError(message = "File '" & $pluginPath &
            "' is already added as a plugin to the shell.", db = db)
      # Check if the plugin can be added
      let newPlugin: PluginData = checkPlugin(pluginPath = pluginPath, db = db,
          commands = commands)
      if newPlugin.path.len == 0:
        return showError(message = "Can't add file '" & $pluginPath &
            "' as the shell's plugins because either it isn't plugin or its API is incompatible with the shell's API.", db = db)
      # Add the plugin to the shell database
      var plugin: Plugin = newPlugin(path = pluginPath, enabled = true,
          preCommand = "preCommand" in newPlugin.api,
          postCommand = "postCommand" in newPlugin.api)
      db.insert(obj = plugin)
      # Execute the installation code of the plugin
      if "install" in newPlugin.api:
        if execPlugin(pluginPath = pluginPath, arguments = ["install"],
            db = db, commands = commands).code != QuitSuccess:
          db.delete(obj = plugin)
          return showError(message = "Can't install plugin '" & $pluginPath &
              "'.", db = db)
      # Execute the enabling code of the plugin
      if "enable" in newPlugin.api:
        if execPlugin(pluginPath = pluginPath, arguments = ["enable"],
            db = db, commands = commands).code != QuitSuccess:
          db.delete(obj = plugin)
          return showError(message = "Can't enable plugin '" & $pluginPath &
              "'.", db = db)
    except:
      return showError(message = "Can't add plugin to the shell. Reason: ",
          e = getCurrentException(), db = db)
    showOutput(message = "File '" & $pluginPath &
        "' added as a plugin to the shell.", color = success, db = db)
    return QuitSuccess.ResultCode

proc getPluginId(arguments; db): Natural {.sideEffect, raises: [],
    tags: [WriteIOEffect, TimeEffect, ReadDbEffect, ReadIOEffect, RootEffect],
    contractual.} =
  ## Get the ID of the plugin. If the user didn't enter the ID, show the list of
  ## plugins and ask the user for ID. Otherwise, check correctness of entered
  ## ID.
  ##
  ## * arguments - the user entered text with arguments for a command
  ## * db        - the connection to the shell's database
  ##
  ## Returns the ID of a plugin or 0 if entered ID was invalid or the user
  ## decided to cancel the command.
  require:
    db != nil
    arguments.len > 0
  body:
    result = 0
    var
      plugin: Plugin = newPlugin()
      actionName: string = ""
      argumentsLen: Positive = 1
    type Check = object
      prefix, actionName: string
    const checks: array[5, Check] = [Check(prefix: "remove",
        actionName: "Removing"), Check(prefix: "show", actionName: "Showing"),
        Check(prefix: "edit", actionName: "Editing"), Check(prefix: "enable",
        actionName: "Enabling"), Check(prefix: "disable",
        actionName: "Disabling")]
    for index, check in checks:
      if arguments.startsWith(prefix = check.prefix):
        actionName = check.actionName
        argumentsLen = check.prefix.len + 2
        break
    if arguments.len < argumentsLen:
      askForName[Plugin](db = db, action = actionName & " a plugin",
            namesType = "plugin", name = plugin)
      if plugin.location.len == 0:
        return 0
      return plugin.id
    result = try:
        parseInt(s = $arguments[argumentsLen - 1 .. ^1])
      except ValueError:
        showError(message = "The Id of the plugin must be a positive number.", db = db)
        return 0
    try:
      if not db.exists(T = Plugin, cond = "id=?", params = $result):
        showError(message = "The plugin with the Id: " & $result &
            " doesn't exists.", db = db)
        return 0
    except:
      showError(message = "Can't find the plugin in database. Reason: ",
          e = getCurrentException(), db = db)
      return 0

proc removePlugin(db; arguments; commands): ResultCode {.sideEffect,
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
    let id: Natural = getPluginId(arguments = arguments, db = db)
    if id == 0:
      return QuitFailure.ResultCode
    try:
      var plugin: Plugin = newPlugin()
      db.select(obj = plugin, cond = "id=?", params = $id)
      # Execute the disabling code of the plugin first
      if execPlugin(pluginPath = plugin.location, arguments = ["disable"],
          db = db, commands = commands).code != QuitSuccess:
        return showError(message = "Can't disable plugin '" & $plugin.location &
            "'.", db = db)
      # Execute the uninstalling code of the plugin
      if execPlugin(pluginPath = plugin.location, arguments = ["uninstall"],
          db = db, commands = commands).code != QuitSuccess:
        return showError(message = "Can't remove plugin '" & $plugin.location &
            "'.", db = db)
      # Remove the plugin from the base
      db.delete(obj = plugin)
    except:
      return showError(message = "Can't delete plugin from database. Reason: ",
          e = getCurrentException(), db = db)
    # Remove the plugin from the list of enabled plugins
    showOutput(message = "Deleted the plugin with Id: " & $id,
        color = success, db = db)
    return QuitSuccess.ResultCode

proc togglePlugin(db; arguments; disable: bool = true;
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
      id: Natural = getPluginId(arguments = arguments, db = db)
      actionName: string = (if disable: "disable" else: "enable")
    if id == 0:
      return QuitFailure.ResultCode
    try:
      var plugin: Plugin = newPlugin()
      db.select(obj = plugin, cond = "id=?", params = $id)
      # Check if plugin can be enabled due to version of API
      let newPlugin: PluginData = checkPlugin(pluginPath = plugin.location,
          db = db, commands = commands)
      if newPlugin.path.len == 0 and not disable:
        return showError(message = "Can't enable plugin with Id: " & $id &
            " because its API version is incompatible with the shell's version.", db = db)
      # Execute the enabling or disabling code of the plugin
      if actionName in newPlugin.api:
        if execPlugin(pluginPath = plugin.location, arguments = [actionName],
            db = db, commands = commands).code != QuitSuccess:
          return showError(message = "Can't " & actionName & " plugin '" &
              $plugin.location & "'.", db = db)
      # Update the state of the plugin
      plugin.enabled = not disable
      db.update(obj = plugin)
      # Remove or add the plugin to the list of enabled plugins and clear
      # the plugin help when disabling it
      if disable:
        db.exec(query = sql(query = ("DELETE FROM help WHERE plugin=?")),
            args = plugin.location)
      elif checkPlugin(pluginPath = plugin.location, db = db,
          commands = commands).path.len == 0:
        return QuitFailure.ResultCode
      showOutput(message = (if disable: "Disabled" else: "Enabled") &
          " the plugin '" & $plugin.location & "'", color = success, db = db)
      return QuitSuccess.ResultCode
    except:
      return showError(message = "Can't " & actionName & " plugin. Reason: ",
          e = getCurrentException(), db = db)

proc listPlugins(arguments; db): ResultCode {.sideEffect, raises: [],
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
        let color: string = getColor(db = db, name = tableHeaders)
        table.add(parts = [style(ss = "ID", style = color), style(ss = "Path",
            style = color), style(ss = "Enabled", style = color)])
      except UnknownEscapeError, InsufficientInputError, FinalByteError:
        return showError(message = "Can't show all plugins list. Reason: ",
            e = getCurrentException(), db = db)
      try:
        var plugins: seq[Plugin] = @[newPlugin()]
        db.selectAll(objs = plugins)
        if plugins.len == 0:
          showOutput(message = "There are no available shell's plugins.", db = db)
          return QuitSuccess.ResultCode
        let color: string = getColor(db = db, name = default)
        for plugin in plugins:
          table.add(parts = [style(ss = plugin.id, style = getColor(db = db,
              name = ids)), style(ss = plugin.location, style = color), style(
              ss = (if plugin.enabled: "Yes" else: "No"), style = color)])
      except:
        return showError(message = "Can't read info about plugin from database. Reason:",
            e = getCurrentException(), db = db)
      var width: int = 0
      for size in table.getColumnSizes(maxSize = int.high):
        width = width + size
      showFormHeader(message = "All available plugins are:",
          width = width.ColumnAmount, db = db)
    # Show the list of enabled plugins
    elif arguments[0..3] == "list":
      try:
        let color: string = getColor(db = db, name = tableHeaders)
        table.add(parts = [style(ss = "ID", style = color), style(ss = "Path",
            style = color)])
      except UnknownEscapeError, InsufficientInputError, FinalByteError:
        return showError(message = "Can't show plugins list. Reason: ",
            e = getCurrentException(), db = db)
      try:
        var plugins: seq[Plugin] = @[newPlugin()]
        db.select(objs = plugins, cond = "enabled=1")
        if plugins.len == 0:
          showOutput(message = "There are no enabled shell's plugins.", db = db)
          return QuitSuccess.ResultCode
        let color: string = getColor(db = db, name = default)
        for plugin in plugins:
          table.add(parts = [style(ss = plugin.id, style = getColor(db = db,
              name = ids)), style(ss = plugin.location, style = color)])
      except:
        return showError(message = "Can't show the list of enabled plugins. Reason: ",
            e = getCurrentException(), db = db)
      var width: int = 0
      for size in table.getColumnSizes(maxSize = int.high):
        width = width + size
      showFormHeader(message = "Enabled plugins are:",
          width = width.ColumnAmount, db = db)
    try:
      table.echoTable
    except IOError, Exception:
      return showError(message = "Can't show the list of plugins. Reason: ",
          e = getCurrentException(), db = db)
    return QuitSuccess.ResultCode

proc showPlugin(arguments; db; commands): ResultCode {.sideEffect, raises: [],
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
    let id: Natural = getPluginId(arguments = arguments, db = db)
    if id == 0:
      return QuitFailure.ResultCode
    try:
      var plugin: Plugin = newPlugin()
      db.select(obj = plugin, cond = "id=?", params = $id)
      var table: TerminalTable = TerminalTable()
      let
        color: string = getColor(db = db, name = showHeaders)
        color2: string = getColor(db = db, name = default)
      table.add(parts = [style(ss = "Id:", style = color), style(ss = $id,
          style = color2)])
      table.add(parts = [style(ss = "Path", style = color), style(
          ss = plugin.location, style = color2)])
      table.add(parts = [style(ss = "Enabled:", style = color), style(ss = (
          if plugin.enabled: "Yes" else: "No"), style = color2)])
      let pluginData: PluginResult = execPlugin(pluginPath = plugin.location,
          arguments = ["info"], db = db, commands = commands)
      # If plugin contains any aditional information, show them
      if pluginData.code == QuitSuccess:
        let pluginInfo: seq[string] = ($pluginData.answer).split(sep = ";")
        table.add(parts = [style(ss = "API version:", style = color), style(
            ss = (if pluginInfo.len > 2: pluginInfo[2] else: "0.1"),
                style = color2)])
        if pluginInfo.len > 2:
          table.add(parts = [style(ss = "API used:", style = color), style(
              ss = pluginInfo[3], style = color2)])
        table.add(parts = [style(ss = "Name:", style = color), style(
            ss = pluginInfo[0], style = color2)])
        if pluginInfo.len > 1:
          table.add(parts = [style(ss = "Descrition:", style = color),
              style(ss = pluginInfo[1], style = color2)])
      else:
        table.add(parts = [style(ss = "API version:", style = color), style(
            ss = "0.1", style = color2)])
      table.echoTable
    except:
      return showError(message = "Can't show the plugin's info. Reason: ",
          e = getCurrentException(), db = db)
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
    proc pluginCommand(arguments: UserInput; db;
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
          return showHelpList(command = "plugin", subcommands = pluginsCommands, db = db)
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
        return showUnknownHelp(subCommand = arguments,
            command = "plugin",
            helpType = "plugin", db = db)
    try:
      addCommand(name = "plugin",
          command = pluginCommand, commands = commands,
          subCommands = pluginsCommands)
    except CommandsListError:
      showError(message = "Can't add commands related to the shell's plugins. Reason: ",
          e = getCurrentException(), db = db)
    # Load all enabled plugins and execute the initialization code of the plugin
    try:
      var plugins: seq[Plugin] = @[newPlugin()]
      db.select(objs = plugins, cond = "1 = 1 ORDER BY id ASC")
      for plugin in plugins.mitems:
        if plugin.enabled:
          let newPlugin: PluginData = checkPlugin(pluginPath = plugin.location,
              db = db, commands = commands)
          if newPlugin.path.len == 0:
            plugin.enabled = false
            db.update(obj = plugin)
            showError(message = "Plugin '" & $plugin.location &
                "' isn't compatible with the current version of shell's API and will be disabled.", db = db)
            continue
          if "init" in newPlugin.api:
            if execPlugin(pluginPath = plugin.location, arguments = ["init"],
                db = db, commands = commands).code != QuitSuccess:
              showError(message = "Can't initialize plugin '" &
                  $plugin.location & "'.", db = db)
              continue
    except:
      showError(message = "Can't read data about the shell's plugins. Reason: ",
          e = getCurrentException(), db = db)

proc updatePluginsDb*(db): ResultCode {.sideEffect, raises: [], tags: [
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
          e = getCurrentException(), db = db)
    return QuitSuccess.ResultCode

