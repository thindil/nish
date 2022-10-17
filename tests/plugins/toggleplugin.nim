discard """
  exitcode: 0
"""

import ../../src/[lstring, nish, plugins, resultcode]
import utils/helpers

var (db, commands) = initTest()
initPlugins(db, commands)
assert setTestPlugin(db, commands) == QuitSuccess
assert togglePlugin(db, initLimitedString(capacity = 9, "disable 1"), true,
    commands) == QuitSuccess
assert togglePlugin(db, initLimitedString(capacity = 8, "enable 1"), false,
    commands) == QuitSuccess
assert togglePlugin(db, initLimitedString(capacity = 8, "enable 2"), false,
    commands) == QuitFailure
quitShell(QuitSuccess.ResultCode, db)
