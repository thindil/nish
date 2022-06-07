discard """
  outputsub: Test variable.
"""

import ../../src/[lstring, nish, variables, resultcode]
import utils/helpers

var (db, _, historyIndex) = initTest()
assert setTestVariables(db) == QuitSuccess
listVariables(initLimitedString(capacity = 4, text = "list"), historyIndex, db)
listVariables(initLimitedString(capacity = 8, text = "list all"), historyIndex, db)
listVariables(initLimitedString(capacity = 8, text = "werwerew"), historyIndex, db)
quitShell(ResultCode(QuitSuccess), db)
