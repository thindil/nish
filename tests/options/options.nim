discard """
  exitcode: 0
"""

import std/tables
import ../../src/[commandslist, directorypath, history, lstring, nish, options, resultcode]

let db =  startDb("test.db".DirectoryPath)
assert db != nil
var commands = newTable[string, CommandData]()
discard initHistory(db, commands)

initOptions(commands)
assert commands.len() > 0

assert getOption(initLimitedString(capacity = 13, text = "historyLength"), db).len() > 0
assert getOption(initLimitedString(capacity = 10, text = "werweewfwe"), db).len() == 0

let optionName = initLimitedString(capacity = 10, text = "testOption")
setOption(optionName = optionName, value = initLimitedString(capacity = 3, text = "200"), db = db)
assert deleteOption(optionName, db) == QuitSuccess
assert getOption(optionName, db).len() == 0

setOption(optionName = initLimitedString(capacity = 13, text = "historyLength"),
    value = initLimitedString(capacity = 3, text = "100"), db = db)
assert getOption(initLimitedString(capacity = 13, text = "historyLength"),
    db) == "100"

assert setOptions(initLimitedString(capacity = 22,
    text = "set historyLength 1000"), db) == QuitSuccess
assert getOption(initLimitedString(capacity = 13, text = "historyLength"),
    db) == "1000"

assert resetOptions(initLimitedString(capacity = 19,
    text = "reset historyLength"), db) == QuitSuccess
assert getOption(initLimitedString(capacity = 13, text = "historyLength"),
    db) == "500"

assert showOptions(db) == QuitSuccess

quitShell(ResultCode(QuitSuccess), db)
