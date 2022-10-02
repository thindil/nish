discard """
  exitcode: 0
"""

import ../../src/[nish, plugins, resultcode]
import utils/helpers

var (db, _, commands) = initTest()
assert checkPlugin("tools/testplugin.sh", db, commands).path == "tools/testplugin.sh"
assert checkPlugin("sdfsdfds.df", db, commands).path.len() == 0
quitShell(QuitSuccess.ResultCode, db)
