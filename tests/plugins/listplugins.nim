discard """
  outputsub: plugins are
"""

import ../../src/[lstring, nish, plugins, resultcode]
import utils/helpers

var (db, commands) = initTest()
initPlugins(db, commands)
assert setTestPlugin(db, commands) == QuitSuccess
assert listPlugins(initLimitedString(capacity = 4, text = "list"), db) == QuitSuccess
assert listPlugins(initLimitedString(capacity = 8, text = "list all"), db) == QuitSuccess
assert listPlugins(initLimitedString(capacity = 8, text = "werwerew"), db) == QuitSuccess
quitShell(ResultCode(QuitSuccess), db)
