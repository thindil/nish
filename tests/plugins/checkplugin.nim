discard """
  exitcode: 0
"""

import ../../src/[nish, plugins, resultcode]
import utils/helpers

var (db, _, _) = initTest()
assert checkPlugin("tools/testplugin.sh", db).path == "tools/testplugin.sh"
assert checkPlugin("sdfsdfds.df", db).path.len() == 0
quitShell(QuitSuccess.ResultCode, db)
