import ../src/[constants, lstring]
import unittest2

suite "Unit tests for lstring module":

  test "Appending a string to a LimitedString":
    checkpoint "Appending a string to a LimitedString"
    var testString: LimitedString = initLimitedString(capacity = 14, text = "test")
    testString.add(" and test")
    check:
      $testString == "test and test"
    testString.add("2")
    check:
      $testString == "test and test2"
    checkpoint "Appending a too long string to a LimitedString"
    expect CapacityError:
      testString.add("very long text outside of max allowed lenght")

  test "Getting length and capacity of a LimitedString":
    let testString: LimitedString = initLimitedString(capacity = 14, text = "test")
    check:
      testString.len == 4
      testString.capacity == 14

  test "Comparison of a LimitedString and a string":
    let testString: LimitedString = initLimitedString(capacity = 4, text = "test")
    checkpoint "Comparing a different LimitedString and a string"
    check:
      testString != "test2"
    checkpoint "Comparing the same LimitedString and a string"
    check:
      testString == "test"

  test "Adding a string to a LimitedString":
    let testString: LimitedString = initLimitedString(capacity = 4, text = "test")
    checkpoint "Appending a string to a LimitedString"
    check:
      testString & "test" == "testtest"
    checkpoint "Prepending a string to a LimitedString"
    check:
      "new" & testString == "newtest"

  test "Converting a LimitedString to a string":
    let testString: LimitedString = initLimitedString(capacity = 4, text = "test")
    check:
      $testString == "test"

  test "emptyLimitedString":
    let testString: LimitedString = emptyLimitedString(maxInputLength)
    check:
      testString.capacity == maxInputLength
      testString == ""

  test "Find a character in a LimiteString":
    let testString: LimitedString = initLimitedString(capacity = 4, text = "test")
    checkpoint "Finding an existing character in a LimitedString"
    check:
      testString.find('e') == 1
    checkpoint "Finding a non-existing character in a LimitedString"
    check:
      testString.find('a') == -1

  test "Assign a too long text to a LimitedString":
    expect CapacityError:
      var testString: LimitedString = initLimitedString(capacity = 4,
          text = "too long text")
      testString = initLimitedString(capacity = 4,
          text = "too long text")

  test "Insert a string into a LimitedString":
    var testString: LimitedString = initLimitedString(capacity = 15, text = "test")
    checkpoint "Inserting a string at the start of a LimitedString"
    testString.insert("start and ")
    check:
      $testString == "start and test"
    checkpoint "Inserting a string at third character in a LimitedString"
    testString.insert("2", 2)
    check:
      $testString == "st2art and test"
    checkpoint "Trying to insert a too long string into a LimitedString"
    expect CapacityError:
      testString.insert("very long text outside of max allowed lenght")

  test "Reverse find of a character in a LimitedString":
    let testString: LimitedString = initLimitedString(capacity = 4, text = "test")
    checkpoint "Reverse find of an existing character in a LimitedString"
    check:
      testString.rfind('a') == -1
    checkpoint "Reverse find of a non-existing character in a LimitedString"
    check:
      testString.rfind('a') == -1

  test "Insert a character into a LimitedString":
    var testString: LimitedString = initLimitedString(capacity = 14, text = "test")
    testString[3] = 'a'
    check:
      $testString == "tesa"

  test "Get a string's slice from a LimitedString":
    let testString: LimitedString = initLimitedString(capacity = 14, text = "test")
    check:
      $testString[1..2] == "es"

  test "Get a character from a LimitedString":
    let testString: LimitedString = initLimitedString(capacity = 4, text = "test")
    check:
      testString[1] == 'e'

  test "Check do a LimitedString starts with the selected string":
    let testString: LimitedString = initLimitedString(capacity = 4, text = "test")
    checkpoint "Positive check for the start of a LimitedString"
    check:
      testString.startsWith("te")
    checkpoint "Negative check for the start of a LimitedString"
    check:
      not testString.startsWith("as")

  test "Set the text property of a LimitedString":
    var testString: LimitedString = initLimitedString(capacity = 10,
        text = "old text")
    checkpoint "Setting the text property of a LimitedString"
    testString.text = "new text"
    check:
      testString == "new text"
    checkpoint "Trying to set too long text property of a LimitedString"
    expect CapacityError:
      testString.text = "very long text which should not go"
