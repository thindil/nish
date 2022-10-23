discard """
  exitcode: 0
"""

import std/tables
import ../../src/[commandslist, directorypath, lstring, nish, plugins, resultcode]

let db = startDb("test.db".DirectoryPath)
assert db != nil
var commands = newTable[string, CommandData]()

initPlugins(db, commands)

discard removePlugin(db, initLimitedString(capacity = 8, "remove 1"), commands)
assert addPlugin(db, initLimitedString(capacity = 23,
    "add tools/testplugin.sh"), commands) == QuitSuccess
assert addPlugin(db, initLimitedString(capacity = 23,
    "add tools/testplugin.sh"), commands) == QuitFailure
assert addPlugin(db, initLimitedString(capacity = 26,
    "add tools/testplugin.223sh"), commands) == QuitFailure

assert checkPlugin("tools/testplugin.sh", db, commands).path == "tools/testplugin.sh"
assert checkPlugin("sdfsdfds.df", db, commands).path.len() == 0

assert execPlugin("tools/testplugin.sh", ["init"], db, commands).code == QuitSuccess
assert execPlugin("tools/testplugin.sh", ["info"], db, commands).answer.len() > 0

assert listPlugins(initLimitedString(capacity = 4, text = "list"), db) == QuitSuccess
assert listPlugins(initLimitedString(capacity = 8, text = "list all"), db) == QuitSuccess
assert listPlugins(initLimitedString(capacity = 8, text = "werwerew"), db) == QuitSuccess

assert togglePlugin(db, initLimitedString(capacity = 9, "disable 1"), true,
    commands) == QuitSuccess
assert togglePlugin(db, initLimitedString(capacity = 8, "enable 1"), false,
    commands) == QuitSuccess
assert togglePlugin(db, initLimitedString(capacity = 8, "enable 2"), false,
    commands) == QuitFailure

assert removePlugin(db, initLimitedString(capacity = 8, "remove 1"),
    commands) == QuitSuccess
assert removePlugin(db, initLimitedString(capacity = 8, "remove 1"),
    commands) == QuitFailure

quitShell(QuitSuccess.ResultCode, db)
