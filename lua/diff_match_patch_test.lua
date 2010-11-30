--[[
* Test Harness for Diff Match and Patch
*
* Copyright 2006 Google Inc.
* http://code.google.com/p/google-diff-match-patch/
*
* Based on the JavaScript implementation by Neil Fraser
* Ported to Lua by Duncan Cross
*
* Licensed under the Apache License, Version 2.0 (the "License");
* you may not use this file except in compliance with the License.
* You may obtain a copy of the License at
*
*   http://www.apache.org/licenses/LICENSE-2.0
*
* Unless required by applicable law or agreed to in writing, software
* distributed under the License is distributed on an "AS IS" BASIS,
* WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
* See the License for the specific language governing permissions and
* limitations under the License.
--]]

local dmp = require 'diff_match_patch'

local DIFF_INSERT = dmp.DIFF_INSERT
local DIFF_DELETE = dmp.DIFF_DELETE
local DIFF_EQUAL = dmp.DIFF_EQUAL

-- Utility functions

local function pretty(v)
  if (type(v) == 'string') then
    return string.format('%q', v):gsub('\\\n', '\\n')
  elseif (type(v) == 'table') then
    local str = {}
    local next_i = 1
    for i, v in pairs(v) do
      if (i == next_i) then
        next_i = next_i + 1
        str[#str + 1] = pretty(v)
      else
        str[#str + 1] = '[' .. pretty(i) .. ']=' .. pretty(v)
      end
    end
    return '{' .. table.concat(str, ',') .. '}'
  else
    return tostring(v)
  end
end

function assertEquals(...)
  local msg, expected, actual
  if (select('#', ...) == 2) then
    expected, actual = ...
    msg = 'Expected: \'' .. pretty(expected)
        .. '\' Actual: \'' .. pretty(actual) .. '\''
  else
    msg, expected, actual = ...
  end
  assert(expected == actual, msg)
end

function assertTrue(...)
  local msg, actual
  if (select('#', ...) == 1) then
    actual = ...
    assertEquals(true, actual)
  else
    msg, actual = ...
    assertEquals(msg, true, actual)
  end
end

function assertFalse(...)
  local msg, actual
  if (select('#', ...) == 1) then
    actual = ...
    assertEquals(flase, actual)
  else
    msg, actual = ...
    assertEquals(msg, false, actual)
  end
end

-- If expected and actual are the equivalent, pass the test.
function assertEquivalent(...)
  local msg, expected, actual
  expected, actual = ...
  msg = 'Expected: \'' .. pretty(expected)
      .. '\' Actual: \'' .. pretty(actual) .. '\''
  if (_equivalent(expected, actual)) then
    assertEquals(msg, pretty(expected), pretty(actual))
  else
    assertEquals(msg, expected, actual)
  end
end

-- Are a and b the equivalent? -- Recursive.
function _equivalent(a, b)
  if (a == b) then
    return true
  end
  if (type(a) == 'table') and (type(b) == 'table') then
    for k, v in pairs(a) do
      if not _equivalent(v, b[k]) then
        return false
      end
    end
    for k, v in pairs(b) do
      if not _equivalent(v, a[k]) then
        return false
      end
    end
    return true
  end
  return false
end

function diff_rebuildtexts(diffs)
  -- Construct the two texts which made up the diff originally.
  local text1, text2 = {}, {}
  for x, diff in ipairs(diffs) do
    local op, data = diff[1], diff[2]
    if (op ~= DIFF_INSERT) then
      text1[#text1 + 1] = data
    end
    if (op ~= DIFF_DELETE) then
      text2[#text2 + 1] = data
    end
  end
  return table.concat(text1), table.concat(text2)
end


-- DIFF TEST FUNCTIONS


function testDiffCommonPrefix()
  -- Detect any common prefix.

  -- Null case.
  assertEquals(0, dmp.diff_commonPrefix('abc', 'xyz'))
  -- Non-null case.
  assertEquals(4, dmp.diff_commonPrefix('1234abcdef', '1234xyz'))
  -- Whole case.
  assertEquals(4, dmp.diff_commonPrefix('1234', '1234xyz'))
end

function testDiffCommonSuffix()
  -- Detect any common suffix.

  -- Null case.
  assertEquals(0, dmp.diff_commonSuffix('abc', 'xyz'))
  -- Non-null case.
  assertEquals(4, dmp.diff_commonSuffix('abcdef1234', 'xyz1234'))
  -- Whole case.
  assertEquals(4, dmp.diff_commonSuffix('1234', 'xyz1234'))
end

function testDiffCommonOverlap()
  -- Detect any suffix/prefix overlap.

  -- Null case.
  assertEquals(0, dmp.diff_commonOverlap('', 'abcd'));
  -- Whole case.
  assertEquals(3, dmp.diff_commonOverlap('abc', 'abcd'));
  -- No overlap.
  assertEquals(0, dmp.diff_commonOverlap('123456', 'abcd'));
  -- Overlap.
  assertEquals(3, dmp.diff_commonOverlap('123456xxx', 'xxxabcd'));
end

function testDiffHalfMatch()
  -- Detect a halfmatch.

  -- No match.
  assertEquivalent({nil}, {dmp.diff_halfMatch('1234567890', 'abcdef')})
  assertEquivalent({nil}, {dmp.diff_halfMatch('12345', '23')})
  -- Single Match.
  assertEquivalent({'12', '90', 'a', 'z', '345678'},
      {dmp.diff_halfMatch('1234567890', 'a345678z')})
  assertEquivalent({'a', 'z', '12', '90', '345678'},
      {dmp.diff_halfMatch('a345678z', '1234567890')})
  assertEquivalent({'abc', 'z', '1234', '0', '56789'},
      {dmp.diff_halfMatch('abc56789z', '1234567890')})
  assertEquivalent({'a', 'xyz', '1', '7890', '23456'},
      {dmp.diff_halfMatch('a23456xyz', '1234567890')})
  -- Multiple Matches.
  assertEquivalent({'12123', '123121', 'a', 'z', '1234123451234'},
      {dmp.diff_halfMatch('121231234123451234123121', 'a1234123451234z')})
  assertEquivalent({'', '-=-=-=-=-=', 'x', '', 'x-=-=-=-=-=-=-='},
      {dmp.diff_halfMatch('x-=-=-=-=-=-=-=-=-=-=-=-=', 'xx-=-=-=-=-=-=-=')})
  assertEquivalent({'-=-=-=-=-=', '', '', 'y', '-=-=-=-=-=-=-=y'},
      {dmp.diff_halfMatch('-=-=-=-=-=-=-=-=-=-=-=-=y', '-=-=-=-=-=-=-=yy')})
end

function testDiffToLines()
  -- Convert lines down to index arrays.
  assertEquivalent({{1, 2, 1}, {2, 1, 2}, {'alpha\n', 'beta\n'}},
      {dmp.diff_toLines('alpha\nbeta\nalpha\n', 'beta\nalpha\nbeta\n')})
  assertEquivalent({{}, {1, 2, 3, 3}, {'alpha\r\n', 'beta\r\n', '\r\n'}},
      {dmp.diff_toLines('', 'alpha\r\nbeta\r\n\r\n\r\n')})
  assertEquivalent({{1}, {2}, {'a', 'b'}}, {dmp.diff_toLines('a', 'b')})

  -- More than 256 to reveal any 8-bit limitations.
  local n = 300
  local lineList = {}
  local lineIndexList = {}
  for x = 1, n do
    lineList[x] = x .. '\n'
    lineIndexList[x] = x
  end
  assertEquals(n, #lineList)
  local lines = table.concat(lineList)
  assertEquivalent({lineIndexList, {}, lineList}, {dmp.diff_toLines(lines, '')})
end

function testDiffFromLines()
  -- Convert chars up to lines.
  local diffs

  diffs = {{DIFF_EQUAL, {1, 2, 1}}, {DIFF_INSERT, {2, 1, 2}}}
  dmp.diff_fromLines(diffs, {'alpha\n', 'beta\n'})
  assertEquivalent(
      {{DIFF_EQUAL, 'alpha\nbeta\nalpha\n'}, {DIFF_INSERT, 'beta\nalpha\nbeta\n'}},
      diffs)

  -- More than 256 to reveal any 8-bit limitations.
  local n = 300
  local lineList = {}
  local lineIndexList = {}
  for x = 1, n do
    lineList[x] = x .. '\n'
    lineIndexList[x] = x
  end
  local lines = table.concat(lineList)
  diffs = {{DIFF_DELETE, lineIndexList}}
  dmp.diff_fromLines(diffs, lineList)
  assertEquivalent({{DIFF_DELETE, lines}}, diffs)
end

function testDiffCleanupMerge()
  -- Cleanup a messy diff.

  -- Null case.
  local diffs = {}
  dmp.diff_cleanupMerge(diffs)
  assertEquivalent({}, diffs)
  -- No change case.
  diffs = {{DIFF_EQUAL, 'a'}, {DIFF_DELETE, 'b'}, {DIFF_INSERT, 'c'}}
  dmp.diff_cleanupMerge(diffs)
  assertEquivalent({{DIFF_EQUAL, 'a'}, {DIFF_DELETE, 'b'}, {DIFF_INSERT, 'c'}},
      diffs)
  -- Merge equalities.
  diffs = {{DIFF_EQUAL, 'a'}, {DIFF_EQUAL, 'b'}, {DIFF_EQUAL, 'c'}}
  dmp.diff_cleanupMerge(diffs)
  assertEquivalent({{DIFF_EQUAL, 'abc'}}, diffs)
  -- Merge deletions.
  diffs = {{DIFF_DELETE, 'a'}, {DIFF_DELETE, 'b'}, {DIFF_DELETE, 'c'}}
  dmp.diff_cleanupMerge(diffs)
  assertEquivalent({{DIFF_DELETE, 'abc'}}, diffs)
  -- Merge insertions.
  diffs = {{DIFF_INSERT, 'a'}, {DIFF_INSERT, 'b'}, {DIFF_INSERT, 'c'}}
  dmp.diff_cleanupMerge(diffs)
  assertEquivalent({{DIFF_INSERT, 'abc'}}, diffs)
  -- Merge interweave.
  diffs = {{DIFF_DELETE, 'a'}, {DIFF_INSERT, 'b'}, {DIFF_DELETE, 'c'},
      {DIFF_INSERT, 'd'}, {DIFF_EQUAL, 'e'}, {DIFF_EQUAL, 'f'}}
  dmp.diff_cleanupMerge(diffs)
  assertEquivalent({{DIFF_DELETE, 'ac'}, {DIFF_INSERT, 'bd'}, {DIFF_EQUAL, 'ef'}},
      diffs)
  -- Prefix and suffix detection.
  diffs = {{DIFF_DELETE, 'a'}, {DIFF_INSERT, 'abc'}, {DIFF_DELETE, 'dc'}}
  dmp.diff_cleanupMerge(diffs)
  assertEquivalent({{DIFF_EQUAL, 'a'}, {DIFF_DELETE, 'd'},
      {DIFF_INSERT, 'b'}, {DIFF_EQUAL, 'c'}}, diffs)
  -- Prefix and suffix detection with equalities.
  diffs = {{DIFF_EQUAL, 'x'}, {DIFF_DELETE, 'a'}, {DIFF_INSERT, 'abc'},
      {DIFF_DELETE, 'dc'}, {DIFF_EQUAL, 'y'}}
  dmp.diff_cleanupMerge(diffs)
  assertEquivalent({{DIFF_EQUAL, 'xa'}, {DIFF_DELETE, 'd'},
      {DIFF_INSERT, 'b'}, {DIFF_EQUAL, 'cy'}}, diffs)
  -- Slide edit left.
  diffs = {{DIFF_EQUAL, 'a'}, {DIFF_INSERT, 'ba'}, {DIFF_EQUAL, 'c'}}
  dmp.diff_cleanupMerge(diffs)
  assertEquivalent({{DIFF_INSERT, 'ab'}, {DIFF_EQUAL, 'ac'}}, diffs)
  -- Slide edit right.
  diffs = {{DIFF_EQUAL, 'c'}, {DIFF_INSERT, 'ab'}, {DIFF_EQUAL, 'a'}}
  dmp.diff_cleanupMerge(diffs)
  assertEquivalent({{DIFF_EQUAL, 'ca'}, {DIFF_INSERT, 'ba'}}, diffs)
  -- Slide edit left recursive.
  diffs = {{DIFF_EQUAL, 'a'}, {DIFF_DELETE, 'b'}, {DIFF_EQUAL, 'c'},
      {DIFF_DELETE, 'ac'}, {DIFF_EQUAL, 'x'}}
  dmp.diff_cleanupMerge(diffs)
  assertEquivalent({{DIFF_DELETE, 'abc'}, {DIFF_EQUAL, 'acx'}}, diffs)
  -- Slide edit right recursive.
  diffs = {{DIFF_EQUAL, 'x'}, {DIFF_DELETE, 'ca'}, {DIFF_EQUAL, 'c'},
      {DIFF_DELETE, 'b'}, {DIFF_EQUAL, 'a'}}
  dmp.diff_cleanupMerge(diffs)
  assertEquivalent({{DIFF_EQUAL, 'xca'}, {DIFF_DELETE, 'cba'}}, diffs)
end

function testDiffCleanupSemanticLossless()
  -- Slide diffs to match logical boundaries.

  -- Null case.
  local diffs = {}
  dmp.diff_cleanupSemanticLossless(diffs)
  assertEquivalent({}, diffs)
  -- Blank lines.
  diffs = {{DIFF_EQUAL, 'AAA\r\n\r\nBBB'}, {DIFF_INSERT, '\r\nDDD\r\n\r\nBBB'},
      {DIFF_EQUAL, '\r\nEEE'}}
  dmp.diff_cleanupSemanticLossless(diffs)
  assertEquivalent({{DIFF_EQUAL, 'AAA\r\n\r\n'},
      {DIFF_INSERT, 'BBB\r\nDDD\r\n\r\n'}, {DIFF_EQUAL, 'BBB\r\nEEE'}}, diffs)
  -- Line boundaries.
  diffs = {{DIFF_EQUAL, 'AAA\r\nBBB'}, {DIFF_INSERT, ' DDD\r\nBBB'},
      {DIFF_EQUAL, ' EEE'}}
  dmp.diff_cleanupSemanticLossless(diffs)
  assertEquivalent({{DIFF_EQUAL, 'AAA\r\n'}, {DIFF_INSERT, 'BBB DDD\r\n'},
      {DIFF_EQUAL, 'BBB EEE'}}, diffs)
  -- Word boundaries.
  diffs = {{DIFF_EQUAL, 'The c'}, {DIFF_INSERT, 'ow and the c'},
      {DIFF_EQUAL, 'at.'}}
  dmp.diff_cleanupSemanticLossless(diffs)
  assertEquivalent({{DIFF_EQUAL, 'The '}, {DIFF_INSERT, 'cow and the '},
      {DIFF_EQUAL, 'cat.'}}, diffs)
  -- Alphanumeric boundaries.
  diffs = {{DIFF_EQUAL, 'The-c'}, {DIFF_INSERT, 'ow-and-the-c'},
      {DIFF_EQUAL, 'at.'}}
  dmp.diff_cleanupSemanticLossless(diffs)
  assertEquivalent({{DIFF_EQUAL, 'The-'}, {DIFF_INSERT, 'cow-and-the-'},
      {DIFF_EQUAL, 'cat.'}}, diffs)
  -- Hitting the start.
  diffs = {{DIFF_EQUAL, 'a'}, {DIFF_DELETE, 'a'}, {DIFF_EQUAL, 'ax'}}
  dmp.diff_cleanupSemanticLossless(diffs)
  assertEquivalent({{DIFF_DELETE, 'a'}, {DIFF_EQUAL, 'aax'}}, diffs)
  -- Hitting the end.
  diffs = {{DIFF_EQUAL, 'xa'}, {DIFF_DELETE, 'a'}, {DIFF_EQUAL, 'a'}}
  dmp.diff_cleanupSemanticLossless(diffs)
  assertEquivalent({{DIFF_EQUAL, 'xaa'}, {DIFF_DELETE, 'a'}}, diffs)
end

function testDiffCleanupSemantic()
  -- Cleanup semantically trivial equalities.

  -- Null case.
  local diffs = {}
  dmp.diff_cleanupSemantic(diffs)
  assertEquivalent({}, diffs)
  -- No elimination #1.
  diffs = {{DIFF_DELETE, 'ab'}, {DIFF_INSERT, 'cd'}, {DIFF_EQUAL, '12'},
      {DIFF_DELETE, 'e'}}
  dmp.diff_cleanupSemantic(diffs)
  assertEquivalent({{DIFF_DELETE, 'ab'}, {DIFF_INSERT, 'cd'}, {DIFF_EQUAL, '12'},
      {DIFF_DELETE, 'e'}}, diffs)
  -- No elimination #2.
  diffs = {{DIFF_DELETE, 'abc'}, {DIFF_INSERT, 'ABC'}, {DIFF_EQUAL, '1234'},
      {DIFF_DELETE, 'wxyz'}}
  dmp.diff_cleanupSemantic(diffs)
  assertEquivalent({{DIFF_DELETE, 'abc'}, {DIFF_INSERT, 'ABC'}, {DIFF_EQUAL, '1234'},
      {DIFF_DELETE, 'wxyz'}}, diffs)
  -- Simple elimination.
  diffs = {{DIFF_DELETE, 'a'}, {DIFF_EQUAL, 'b'}, {DIFF_DELETE, 'c'}}
  dmp.diff_cleanupSemantic(diffs)
  assertEquivalent({{DIFF_DELETE, 'abc'}, {DIFF_INSERT, 'b'}}, diffs)
  -- Backpass elimination.
  diffs = {{DIFF_DELETE, 'ab'}, {DIFF_EQUAL, 'cd'}, {DIFF_DELETE, 'e'},
      {DIFF_EQUAL, 'f'}, {DIFF_INSERT, 'g'}}
  dmp.diff_cleanupSemantic(diffs)
  assertEquivalent({{DIFF_DELETE, 'abcdef'}, {DIFF_INSERT, 'cdfg'}}, diffs)
  -- Multiple eliminations.
  diffs = {{DIFF_INSERT, '1'}, {DIFF_EQUAL, 'A'}, {DIFF_DELETE, 'B'},
      {DIFF_INSERT, '2'}, {DIFF_EQUAL, '_'}, {DIFF_INSERT, '1'},
      {DIFF_EQUAL, 'A'}, {DIFF_DELETE, 'B'}, {DIFF_INSERT, '2'}}
  dmp.diff_cleanupSemantic(diffs)
  assertEquivalent({{DIFF_DELETE, 'AB_AB'}, {DIFF_INSERT, '1A2_1A2'}}, diffs)
  -- Word boundaries.
  diffs = {{DIFF_EQUAL, 'The c'}, {DIFF_DELETE, 'ow and the c'},
      {DIFF_EQUAL, 'at.'}}
  dmp.diff_cleanupSemantic(diffs)
  assertEquivalent({{DIFF_EQUAL, 'The '}, {DIFF_DELETE, 'cow and the '},
      {DIFF_EQUAL, 'cat.'}}, diffs)
  -- Overlap elimination.
  diffs = {{DIFF_DELETE, 'abcxx'}, {DIFF_INSERT, 'xxdef'}}
  dmp.diff_cleanupSemantic(diffs)
  assertEquivalent({{DIFF_DELETE, 'abc'}, {DIFF_EQUAL, 'xx'}, {DIFF_INSERT, 'def'}}, diffs)
end

function testDiffCleanupEfficiency()
  -- Cleanup operationally trivial equalities.
  local diffs
  dmp.settings{Diff_EditCost = 4}

  -- Null case.
  diffs = {}
  dmp.diff_cleanupEfficiency(diffs)
  assertEquivalent({}, diffs)
  -- No elimination.
  diffs = {{DIFF_DELETE, 'ab'}, {DIFF_INSERT, '12'}, {DIFF_EQUAL, 'wxyz'},
      {DIFF_DELETE, 'cd'}, {DIFF_INSERT, '34'}}
  dmp.diff_cleanupEfficiency(diffs)
  assertEquivalent({{DIFF_DELETE, 'ab'}, {DIFF_INSERT, '12'},
      {DIFF_EQUAL, 'wxyz'}, {DIFF_DELETE, 'cd'}, {DIFF_INSERT, '34'}}, diffs)
  -- Four-edit elimination.
  diffs = {{DIFF_DELETE, 'ab'}, {DIFF_INSERT, '12'}, {DIFF_EQUAL, 'xyz'},
      {DIFF_DELETE, 'cd'}, {DIFF_INSERT, '34'}}
  dmp.diff_cleanupEfficiency(diffs)
  assertEquivalent({
        {DIFF_DELETE, 'abxyzcd'},
        {DIFF_INSERT, '12xyz34'}
      }, diffs)

  -- Three-edit elimination.
  diffs = {
        {DIFF_INSERT, '12'},
        {DIFF_EQUAL, 'x'},
        {DIFF_DELETE, 'cd'},
        {DIFF_INSERT, '34'}
      }
  dmp.diff_cleanupEfficiency(diffs)
  assertEquivalent({
        {DIFF_DELETE, 'xcd'},
        {DIFF_INSERT, '12x34'}
      }, diffs)

  -- Backpass elimination.
  diffs = {
        {DIFF_DELETE, 'ab'},
        {DIFF_INSERT, '12'},
        {DIFF_EQUAL, 'xy'},
        {DIFF_INSERT, '34'},
        {DIFF_EQUAL, 'z'},
        {DIFF_DELETE, 'cd'},
        {DIFF_INSERT, '56'}
      }
  dmp.diff_cleanupEfficiency(diffs)
  assertEquivalent({
        {DIFF_DELETE, 'abxyzcd'},
        {DIFF_INSERT, '12xy34z56'}
      }, diffs)

  -- High cost elimination.
  dmp.settings{Diff_EditCost = 5}
  diffs = {
        {DIFF_DELETE, 'ab'},
        {DIFF_INSERT, '12'},
        {DIFF_EQUAL, 'wxyz'},
        {DIFF_DELETE, 'cd'},
        {DIFF_INSERT, '34'}
      }
  dmp.diff_cleanupEfficiency(diffs)
  assertEquivalent({
        {DIFF_DELETE, 'abwxyzcd'},
        {DIFF_INSERT, '12wxyz34'}
      }, diffs)

  dmp.settings{Diff_EditCost = 4}
end

function testDiffPrettyHtml()
  -- Pretty print.
  local diffs = {
        {DIFF_EQUAL, 'a\n'},
        {DIFF_DELETE, '<B>b</B>'},
        {DIFF_INSERT, 'c&d'}
      }
  assertEquals(
        '<SPAN TITLE="i=0">a&para;<BR></SPAN>'
        .. '<DEL STYLE="background:#FFE6E6;" TITLE="i=2">&lt;B&gt;b&lt;/B&gt;'
        .. '</DEL><INS STYLE="background:#E6FFE6;" TITLE="i=2">c&amp;d</INS>',
        dmp.diff_prettyHtml(diffs)
      )
end

function testDiffText()
  -- Compute the source and destination texts.
  local diffs = {
        {DIFF_EQUAL, 'jump'},
        {DIFF_DELETE, 's'},
        {DIFF_INSERT, 'ed'},
        {DIFF_EQUAL, ' over '},
        {DIFF_DELETE, 'the'},
        {DIFF_INSERT, 'a'},
        {DIFF_EQUAL, ' lazy'}
      }
  assertEquals('jumps over the lazy', dmp.diff_text1(diffs))
  assertEquals('jumped over a lazy', dmp.diff_text2(diffs))
end

function testDiffDelta()
  -- Convert a diff into delta string.
  local diffs = {
        {DIFF_EQUAL, 'jump'},
        {DIFF_DELETE, 's'},
        {DIFF_INSERT, 'ed'},
        {DIFF_EQUAL, ' over '},
        {DIFF_DELETE, 'the'},
        {DIFF_INSERT, 'a'},
        {DIFF_EQUAL, ' lazy'},
        {DIFF_INSERT, 'old dog'}
      }
  local text1 = dmp.diff_text1(diffs)
  assertEquals('jumps over the lazy', text1)

  local delta = dmp.diff_toDelta(diffs)
  assertEquals('=4\t-1\t+ed\t=6\t-3\t+a\t=5\t+old dog', delta)

  -- Convert delta string into a diff.
  assertEquivalent(diffs, dmp.diff_fromDelta(text1, delta))

  -- Generates error (19 ~= 20).
  success, result = pcall(dmp.diff_fromDelta, text1 .. 'x', delta)
  assertEquals(false, success)

  -- Generates error (19 ~= 18).
  success, result = pcall(dmp.diff_fromDelta, string.sub(text1, 2), delta)
  assertEquals(false, success)

  -- Generates error (%c3%xy invalid Unicode).
  success, result = pcall(dmp.patch_fromDelta, '', '+%c3%xy')
  assertEquals(false, success)

  --[[
  -- Test deltas with special characters.
  -- TODO: Make this test pass.
  diffs = {{DIFF_EQUAL, '\u0680 \000 \t %'}, {DIFF_DELETE, '\u0681 \x01 \n ^'}, {DIFF_INSERT, '\u0682 \x02 \\ |'}}
  text1 = dmp.diff_text1(diffs)
  assertEquals('\u0680 \x00 \t %\u0681 \x01 \n ^', text1)

  delta = dmp.diff_toDelta(diffs)
  assertEquals('=7\t-7\t+%DA%82 %02 %5C %7C', delta)
  --]]

  -- Convert delta string into a diff.
  assertEquivalent(diffs, dmp.diff_fromDelta(text1, delta))

  -- Verify pool of unchanged characters.
  diffs = {
        {DIFF_INSERT, 'A-Z a-z 0-9 - _ . ! ~ * \' ( ) ; / ? = @ & = + $ , # '}
      }
  local text2 = dmp.diff_text2(diffs)
  assertEquals(
        'A-Z a-z 0-9 - _ . ! ~ * \' ( ) ; / ? = @ & = + $ , # ',
        text2
      )

  delta = dmp.diff_toDelta(diffs)
  assertEquals(
        '+A-Z a-z 0-9 - _ . ! ~ * \' ( ) ; / ? = @ & = + $ , # ',
        delta
      )

  -- Convert delta string into a diff.
  assertEquivalent(diffs, dmp.diff_fromDelta('', delta))
end

function testDiffXIndex()
  -- Translate a location in text1 to text2.

  -- Translation on equality.
  assertEquals(6, dmp.diff_xIndex({
        {DIFF_DELETE, 'a'},
        {DIFF_INSERT, '1234'},
        {DIFF_EQUAL, 'xyz'}
      }, 3))

  -- Translation on deletion.
  assertEquals(2, dmp.diff_xIndex({
        {DIFF_EQUAL, 'a'},
        {DIFF_DELETE, '1234'},
        {DIFF_EQUAL, 'xyz'}
      }, 4))
end

function testDiffLevenshtein()
  -- Levenshtein with trailing equality.
  assertEquals(4, dmp.diff_levenshtein({
        {DIFF_DELETE, 'abc'},
        {DIFF_INSERT, '1234'},
        {DIFF_EQUAL, 'xyz'}
      }))
  -- Levenshtein with leading equality.
  assertEquals(4, dmp.diff_levenshtein({
        {DIFF_EQUAL, 'xyz'},
        {DIFF_DELETE, 'abc'},
        {DIFF_INSERT, '1234'}
      }))
  -- Levenshtein with middle equality.
  assertEquals(7, dmp.diff_levenshtein({
        {DIFF_DELETE, 'abc'},
        {DIFF_EQUAL, 'xyz'},
        {DIFF_INSERT, '1234'}
      }))
end

function testDiffPath()
  -- Single letters.
  -- Trace a path from back to front.
  local v_map = {
      { [0]=1},
      {[-1]=1,  [1]=2},
      {[-2]=1,  [2]=3,  [0]=3},
      {[-3]=1, [-1]=3,  [3]=4, [1]=5},
      {[-4]=1, [-2]=3,  [4]=5, [0]=5, [2]=6},
      {[-5]=1, [-3]=3, [-1]=5, [5]=6, [3]=7, [1]=7},
      {[-6]=1, [-4]=3, [-2]=5, [0]=7, [2]=8}
  }
  assertEquivalent({
        {DIFF_INSERT, 'W'},
        {DIFF_DELETE, 'A'},
        {DIFF_EQUAL, '1'},
        {DIFF_DELETE, 'B'},
        {DIFF_EQUAL, '2'},
        {DIFF_INSERT, 'X'},
        {DIFF_DELETE, 'C'},
        {DIFF_EQUAL, '3'},
        {DIFF_DELETE, 'D'}
      }, dmp.diff_path1(v_map, 'A1B2C3D', 'W12X3'))

  -- Trace a path from front to back.
  v_map[#v_map] = nil
  assertEquivalent({
        {DIFF_EQUAL, '4'},
        {DIFF_DELETE, 'E'},
        {DIFF_INSERT, 'Y'},
        {DIFF_EQUAL, '5'},
        {DIFF_DELETE, 'F'},
        {DIFF_EQUAL, '6'},
        {DIFF_DELETE, 'G'},
        {DIFF_INSERT, 'Z'}
      }, dmp.diff_path2(v_map, '4E5F6G', '4Y56Z'))

  -- Double letters
  -- Trace a path from back to front.
  v_map = {
    { [0]=1},
    {[-1]=1,  [1]=2},
    {[-2]=1,  [0]=2, [2]=3},
    {[-3]=1, [-1]=2, [1]=3, [3]=4},
    {[-4]=1, [-2]=2, [2]=4, [4]=5, [0]=5}
  }
  assertEquivalent({
        {DIFF_INSERT, 'WX'},
        {DIFF_DELETE, 'AB'},
        {DIFF_EQUAL, '12'}
      }, dmp.diff_path1(v_map, 'AB12', 'WX12'))

  -- Trace a path from front to back.
  v_map = {
    { [0]=1},
    {[-1]=1,  [1]=2},
    { [0]=2,  [2]=3, [-2]=3},
    { [1]=3, [-3]=3,  [3]=4, [-1]=4},
    {[-4]=3, [-2]=4,  [0]=5}
  }
  assertEquivalent({
        {DIFF_DELETE, 'CD'},
        {DIFF_EQUAL, '34'},
        {DIFF_INSERT, 'YZ'}
    }, dmp.diff_path2(v_map, 'CD34', '34YZ'))
end

function testDiffMap()
  -- Normal.
  local a = 'cat'
  local b = 'map'
  -- Since the resulting diff hasn't been normalized, it would be ok if
  -- the insertion and deletion pairs are swapped.
  -- If the order changes, tweak this test as required.
  assertEquivalent({
        {DIFF_INSERT, 'm'},
        {DIFF_DELETE, 'c'},
        {DIFF_EQUAL, 'a'},
        {DIFF_INSERT, 'p'},
        {DIFF_DELETE, 't'}
      }, dmp.diff_map(a, b, 2 ^ 31))

  -- Timeout.
  assertEquivalent({
        {DIFF_DELETE, 'cat'},
        {DIFF_INSERT, 'map'}
      }, dmp.diff_map(a, b, 0))
end

function testDiffMain()
  -- Perform a trivial diff.
  local a,b

  -- Null case.
  assertEquivalent({}, dmp.diff_main('', '', false))

  -- Equality.
  assertEquivalent({
        {DIFF_EQUAL, 'abc'}
      }, dmp.diff_main('abc', 'abc', false))

  -- Simple insertion.
  assertEquivalent({
        {DIFF_EQUAL, 'ab'},
        {DIFF_INSERT, '123'},
        {DIFF_EQUAL, 'c'}
      }, dmp.diff_main('abc', 'ab123c', false))

  -- Simple deletion.
  assertEquivalent({
        {DIFF_EQUAL, 'a'},
        {DIFF_DELETE, '123'},
        {DIFF_EQUAL, 'bc'}
      }, dmp.diff_main('a123bc', 'abc', false))

  -- Two insertions.
  assertEquivalent({
        {DIFF_EQUAL, 'a'},
        {DIFF_INSERT, '123'},
        {DIFF_EQUAL, 'b'},
        {DIFF_INSERT, '456'},
        {DIFF_EQUAL, 'c'}
      }, dmp.diff_main('abc', 'a123b456c', false))

  -- Two deletions.
  assertEquivalent({
        {DIFF_EQUAL, 'a'},
        {DIFF_DELETE, '123'},
        {DIFF_EQUAL, 'b'},
        {DIFF_DELETE, '456'},
        {DIFF_EQUAL, 'c'}
      }, dmp.diff_main('a123b456c', 'abc', false))

  -- Perform a real diff.
  -- Switch off the timeout.
  dmp.settings{ Diff_Timeout=0, Diff_DualThreshold=32 }

  -- Simple cases.
  assertEquivalent({
        {DIFF_DELETE, 'a'},
        {DIFF_INSERT, 'b'}
      }, dmp.diff_main('a', 'b', false))

  assertEquivalent({
        {DIFF_DELETE, 'Apple'},
        {DIFF_INSERT, 'Banana'},
        {DIFF_EQUAL, 's are a'},
        {DIFF_INSERT, 'lso'},
        {DIFF_EQUAL, ' fruit.'}
      }, dmp.diff_main('Apples are a fruit.', 'Bananas are also fruit.', false))

  assertEquivalent({
        {DIFF_DELETE, 'a'},
        {DIFF_INSERT, '\u0680'},
        {DIFF_EQUAL, 'x'},
        {DIFF_DELETE, '\t'},
        {DIFF_INSERT, '\0'}
      }, dmp.diff_main('ax\t', '\u0680x\0', false))

  -- Overlaps.
  assertEquivalent({
        {DIFF_DELETE, '1'},
        {DIFF_EQUAL, 'a'},
        {DIFF_DELETE, 'y'},
        {DIFF_EQUAL, 'b'},
        {DIFF_DELETE, '2'},
        {DIFF_INSERT, 'xab'}
      }, dmp.diff_main('1ayb2', 'abxab', false))
  assertEquivalent({
        {DIFF_INSERT, 'xaxcx'},
        {DIFF_EQUAL, 'abc'},
        {DIFF_DELETE, 'y'}
      }, dmp.diff_main('abcy', 'xaxcxabc', false))

  -- Sub-optimal double-ended diff.
  dmp.settings{Diff_DualThreshold = 2}
  assertEquivalent({
        {DIFF_INSERT, 'x'},
        {DIFF_EQUAL, 'a'},
        {DIFF_DELETE, 'b'},
        {DIFF_INSERT, 'x'},
        {DIFF_EQUAL, 'c'},
        {DIFF_DELETE, 'y'},
        {DIFF_INSERT, 'xabc'}
      }, dmp.diff_main('abcy', 'xaxcxabc', false))
  dmp.settings{Diff_DualThreshold = 32}

  -- Timeout.
  dmp.settings{Diff_Timeout = 0.1}  -- 100ms
  -- Increase the text lengths by 1024 times to ensure a timeout.
  a = string.rep([[
`Twas brillig, and the slithy toves
Did gyre and gimble in the wabe:
All mimsy were the borogoves,
And the mome raths outgrabe.
]], 1024)
  b = string.rep([[
I am the very model of a modern major general,
I've information vegetable, animal, and mineral,
I know the kings of England, and I quote the fights historical,
From Marathon to Waterloo, in order categorical.
]], 1024)
  local startTime = os.clock()
  dmp.diff_main(a, b)
  local endTime = os.clock()
  -- Test that we took at least the timeout period.
  assertTrue(0.1 <= endTime - startTime)
  -- Test that we didn't take forever (be forgiving).
  -- Theoretically this test could fail very occasionally if the
  -- OS task swaps or locks up for a second at the wrong moment.
  assertTrue(0.1 * 2 > endTime - startTime)
  dmp.settings{Diff_Timeout = 0}

  -- Test the linemode speedup.
  -- Must be long to pass the 200 char cutoff.
  a = string.rep('1234567890\n', 13)
  b = string.rep('abcdefghij\n', 13)
  assertEquivalent(dmp.diff_main(a, b, false), dmp.diff_main(a, b, true))

  a = string.rep('1234567890\n', 13)
  b = [[
abcdefghij
1234567890
1234567890
1234567890
abcdefghij
1234567890
1234567890
1234567890
abcdefghij
1234567890
1234567890
1234567890
abcdefghij
]]

  local texts_linemode = diff_rebuildtexts(dmp.diff_main(a, b, true))
  local texts_textmode = diff_rebuildtexts(dmp.diff_main(a, b, false))
  assertEquivalent(texts_textmode, texts_linemode)

  -- Test null inputs.
  success, result = pcall(dmp.diff_main, nil, nil)
  assertEquals(false, success)
end


-- MATCH TEST FUNCTIONS


function testMatchAlphabet()
  -- Initialise the bitmasks for Bitap.
  -- Unique.
  assertEquivalent({a=4, b=2, c=1}, dmp.match_alphabet('abc'))

  -- Duplicates.
  assertEquivalent({a=37, b=18, c=8}, dmp.match_alphabet('abcaba'))
end

function testMatchBitap()
  -- Bitap algorithm.
  dmp.settings{Match_Distance=100, Match_Threshold=0.5}

  -- Exact matches.
  assertEquals(6, dmp.match_bitap('abcdefghijk', 'fgh', 6))

  assertEquals(6, dmp.match_bitap('abcdefghijk', 'fgh', 1))

  -- Fuzzy matches.
  assertEquals(5, dmp.match_bitap('abcdefghijk', 'efxhi', 1))

  assertEquals(3, dmp.match_bitap('abcdefghijk', 'cdefxyhijk', 6))

  assertEquals(-1, dmp.match_bitap('abcdefghijk', 'bxy', 2))

  -- Overflow.
  assertEquals(3, dmp.match_bitap('123456789xx0', '3456789x0', 3))

  -- Threshold test.
  dmp.settings{Match_Threshold = 0.4}
  assertEquals(5, dmp.match_bitap('abcdefghijk', 'efxyhi', 2))

  dmp.settings{Match_Threshold = 0.3}
  assertEquals(-1, dmp.match_bitap('abcdefghijk', 'efxyhi', 2))

  dmp.settings{Match_Threshold = 0.0}
  assertEquals(2, dmp.match_bitap('abcdefghijk', 'bcdef', 2))
  dmp.settings{Match_Threshold = 0.5}

  -- Multiple select.
  assertEquals(1, dmp.match_bitap('abcdexyzabcde', 'abccde', 4))

  assertEquals(9, dmp.match_bitap('abcdexyzabcde', 'abccde', 6))

  -- Distance test.

  dmp.settings{Match_Distance = 10}  -- Strict location.

  assertEquals(-1,
      dmp.match_bitap('abcdefghijklmnopqrstuvwxyz', 'abcdefg', 25))

  assertEquals(1,
      dmp.match_bitap('abcdefghijklmnopqrstuvwxyz', 'abcdxxefg', 2))

  dmp.settings{Match_Distance = 1000}  -- Loose location.

  assertEquals(1,
      dmp.match_bitap('abcdefghijklmnopqrstuvwxyz', 'abcdefg', 25))
end

function testMatchMain()
  -- Full match.
  -- Shortcut matches.
  assertEquals(1, dmp.match_main('abcdef', 'abcdef', 1000))

  assertEquals(-1, dmp.match_main('', 'abcdef', 2))

  assertEquals(4, dmp.match_main('abcdef', '', 4))

  assertEquals(4, dmp.match_main('abcdef', 'de', 4))

  -- Beyond end match.
  assertEquals(4, dmp.match_main("abcdef", "defy", 5))

  -- Oversized pattern.
  assertEquals(1, dmp.match_main("abcdef", "abcdefy", 1))

  -- Complex match.
  assertEquals(5, dmp.match_main(
        'I am the very model of a modern major general.',
        ' that berry ',
        6
      ))

  -- Test null inputs.
  success, result = pcall(dmp.match_main, nil, nil, 0)
  assertEquals(false, success)
end


-- PATCH TEST FUNCTIONS


function testPatchObj()
  -- Patch Object.
  local p = dmp.new_patch_obj()
  p.start1 = 21
  p.start2 = 22
  p.length1 = 18
  p.length2 = 17
  p.diffs = {
        {DIFF_EQUAL, 'jump'},
        {DIFF_DELETE, 's'},
        {DIFF_INSERT, 'ed'},
        {DIFF_EQUAL, ' over '},
        {DIFF_DELETE, 'the'},
        {DIFF_INSERT, 'a'},
        {DIFF_EQUAL, '\nlaz'}
      }
  local strp = tostring(p)
  assertEquals(
        '@@ -21,18 +22,17 @@\n jump\n-s\n+ed\n  over \n-the\n+a\n %0Alaz\n',
        strp
      )
end

function testPatchFromText()
  local strp

  strp = ''
  assertEquivalent({}, dmp.patch_fromText(strp))

  strp = '@@ -21,18 +22,17 @@\n jump\n-s\n+ed\n  over \n-the\n+a\n %0Alaz\n'
  assertEquals(strp, tostring(dmp.patch_fromText(strp)[1]))

  assertEquals(
        '@@ -1 +1 @@\n-a\n+b\n',
        tostring(dmp.patch_fromText('@@ -1 +1 @@\n-a\n+b\n')[1])
      )

  assertEquals(
        '@@ -1,3 +0,0 @@\n-abc\n',
        tostring(dmp.patch_fromText('@@ -1,3 +0,0 @@\n-abc\n')[1])
      )

  assertEquals(
        '@@ -0,0 +1,3 @@\n+abc\n',
        tostring(dmp.patch_fromText('@@ -0,0 +1,3 @@\n+abc\n')[1])
      )

  -- Generates error.
  success, result = pcall(dmp.patch_fromText, 'Bad\nPatch\n')
  assertEquals(false, success)
end

function testPatchToText()
  local strp, p

  strp = '@@ -21,18 +22,17 @@\n jump\n-s\n+ed\n  over \n-the\n+a\n  laz\n'
  p = dmp.patch_fromText(strp)
  assertEquals(strp, dmp.patch_toText(p))

  strp = '@@ -1,9 +1,9 @@\n-f\n+F\n oo+fooba\n'
      .. '@@ -7,9 +7,9 @@\n obar\n-,\n+.\n  tes\n'
  p = dmp.patch_fromText(strp)
  assertEquals(strp, dmp.patch_toText(p))
end

function testPatchAddContext()
  local p
  dmp.settings{Patch_Margin = 4}

  p = dmp.patch_fromText('@@ -21,4 +21,10 @@\n-jump\n+somersault\n')[1]

  dmp.patch_addContext(p, 'The quick brown fox jumps over the lazy dog.')

  assertEquals(
        '@@ -17,12 +17,18 @@\n fox \n-jump\n+somersault\n s ov\n',
        tostring(p)
      )

  -- Same, but not enough trailing context.
  p = dmp.patch_fromText('@@ -21,4 +21,10 @@\n-jump\n+somersault\n')[1]
  dmp.patch_addContext(p, 'The quick brown fox jumps.')
  assertEquals(
        '@@ -17,10 +17,16 @@\n fox \n-jump\n+somersault\n s.\n',
        tostring(p)
      )

  -- Same, but not enough leading context.
  p = dmp.patch_fromText('@@ -3 +3,2 @@\n-e\n+at\n')[1]
  dmp.patch_addContext(p, 'The quick brown fox jumps.')
  assertEquals('@@ -1,7 +1,8 @@\n Th\n-e\n+at\n  qui\n', tostring(p))

  -- Same, but with ambiguity.
  p = dmp.patch_fromText('@@ -3 +3,2 @@\n-e\n+at\n')[1]
  dmp.patch_addContext(p, 'The quick brown fox jumps.  The quick brown fox crashes.')
  assertEquals('@@ -1,27 +1,28 @@\n Th\n-e\n+at\n  quick brown fox jumps. \n', tostring(p))
end

function testPatchMake()
  -- Null case.
  local patches = dmp.patch_make('', '')
  assertEquals('', dmp.patch_toText(patches))

  local text1 = 'The quick brown fox jumps over the lazy dog.'
  local text2 = 'That quick brown fox jumped over a lazy dog.'
  -- Text2+Text1 inputs.
  local expectedPatch = '@@ -1,8 +1,7 @@\n Th\n-at\n+e\n  qui\n'
      .. '@@ -21,17 +21,18 @@\n jump\n-ed\n+s\n  over \n-a\n+the\n  laz\n'
  -- The second patch must be "-21,17 +21,18",
  -- not "-22,17 +21,18" due to rolling context.
  patches = dmp.patch_make(text2, text1)
  assertEquals(expectedPatch, dmp.patch_toText(patches))

  -- Text1+Text2 inputs.
  expectedPatch = '@@ -1,11 +1,12 @@\n Th\n-e\n+at\n  quick b\n'
      .. '@@ -22,18 +22,17 @@\n jump\n-s\n+ed\n  over \n-the\n+a\n  laz\n'
  patches = dmp.patch_make(text1, text2)
  assertEquals(expectedPatch, dmp.patch_toText(patches))

  -- Diff input.
  local diffs = dmp.diff_main(text1, text2, false)
  patches = dmp.patch_make(diffs)
  assertEquals(expectedPatch, dmp.patch_toText(patches))

  -- Text1+Diff inputs.
  patches = dmp.patch_make(text1, diffs)
  assertEquals(expectedPatch, dmp.patch_toText(patches))

  -- Text1+Text2+Diff inputs (deprecated).
  patches = dmp.patch_make(text1, text2, diffs)
  assertEquals(expectedPatch, dmp.patch_toText(patches))

  -- Character encoding.
  patches = dmp.patch_make('`1234567890-=[]\\;\',./', '~!@#$%^&*()_+{}|="<>?')
  assertEquals('@@ -1,21 +1,21 @@\n'
      .. '-%601234567890-=%5B%5D%5C;\',./\n'
      .. '+~!@#$%25%5E&*()_+%7B%7D%7C=%22%3C%3E?\n', dmp.patch_toText(patches))

  -- Character decoding.
  diffs = {
        {DIFF_DELETE, '`1234567890-=[]\\;\',./'},
        {DIFF_INSERT, '~!@#$%^&*()_+{}|="<>?'}
      }
  assertEquivalent(diffs, dmp.patch_fromText(
        '@@ -1,21 +1,21 @@'
         .. '\n-%601234567890-=%5B%5D%5C;\',./'
         .. '\n+~!@#$%25%5E&*()_+%7B%7D%7C=%22%3C%3E?\n'
      )[1].diffs)

  -- Long string with repeats.
  text1 = string.rep('abcdef', 100)
  text2 = text1 .. '123'
  expectedPatch = '@@ -573,28 +573,31 @@\n'
      .. ' cdefabcdefabcdefabcdefabcdef\n+123\n'
  patches = dmp.patch_make(text1, text2)
  assertEquals(expectedPatch, dmp.patch_toText(patches))

  -- Test null inputs.
  success, result = pcall(dmp.patch_make, nil, nil)
  assertEquals(false, success)
end

function testPatchSplitMax()
  -- Assumes that dmp.Match_MaxBits is 32.
  local patches = dmp.patch_make('abcdefghijklmnopqrstuvwxyz01234567890',
      'XabXcdXefXghXijXklXmnXopXqrXstXuvXwxXyzX01X23X45X67X89X0')
  dmp.patch_splitMax(patches)
  assertEquals('@@ -1,32 +1,46 @@\n+X\n ab\n+X\n cd\n+X\n ef\n+X\n gh\n+X\n ij\n+X\n kl\n+X\n mn\n+X\n op\n+X\n qr\n+X\n st\n+X\n uv\n+X\n wx\n+X\n yz\n+X\n 012345\n@@ -25,13 +39,18 @@\n zX01\n+X\n 23\n+X\n 45\n+X\n 67\n+X\n 89\n+X\n 0\n', dmp.patch_toText(patches))

  patches = dmp.patch_make('abcdef1234567890123456789012345678901234567890123456789012345678901234567890uvwxyz', 'abcdefuvwxyz')
  local oldToText = dmp.patch_toText(patches)
  dmp.patch_splitMax(patches)
  assertEquals(oldToText, dmp.patch_toText(patches))

  patches = dmp.patch_make('1234567890123456789012345678901234567890123456789012345678901234567890', 'abc')
  dmp.patch_splitMax(patches)
  assertEquals('@@ -1,32 +1,4 @@\n-1234567890123456789012345678\n 9012\n@@ -29,32 +1,4 @@\n-9012345678901234567890123456\n 7890\n@@ -57,14 +1,3 @@\n-78901234567890\n+abc\n', dmp.patch_toText(patches))

  patches = dmp.patch_make('abcdefghij , h = 0 , t = 1 abcdefghij , h = 0 , t = 1 abcdefghij , h = 0 , t = 1', 'abcdefghij , h = 1 , t = 1 abcdefghij , h = 1 , t = 1 abcdefghij , h = 0 , t = 1')
  dmp.patch_splitMax(patches)
  assertEquals('@@ -2,32 +2,32 @@\n bcdefghij , h = \n-0\n+1\n  , t = 1 abcdef\n@@ -29,32 +29,32 @@\n bcdefghij , h = \n-0\n+1\n  , t = 1 abcdef\n', dmp.patch_toText(patches))
end

function testPatchAddPadding()
  -- Both edges full.
  local patches = dmp.patch_make('', 'test')
  assertEquals('@@ -0,0 +1,4 @@\n+test\n', dmp.patch_toText(patches))
  dmp.patch_addPadding(patches)
  assertEquals('@@ -1,8 +1,12 @@\n %01%02%03%04\n+test\n %01%02%03%04\n', dmp.patch_toText(patches))

  -- Both edges partial.
  patches = dmp.patch_make('XY', 'XtestY')
  assertEquals('@@ -1,2 +1,6 @@\n X\n+test\n Y\n', dmp.patch_toText(patches))
  dmp.patch_addPadding(patches)
  assertEquals('@@ -2,8 +2,12 @@\n %02%03%04X\n+test\n Y%01%02%03\n', dmp.patch_toText(patches))

  -- Both edges none.
  patches = dmp.patch_make('XXXXYYYY', 'XXXXtestYYYY')
  assertEquals('@@ -1,8 +1,12 @@\n XXXX\n+test\n YYYY\n', dmp.patch_toText(patches))
  dmp.patch_addPadding(patches)
  assertEquals('@@ -5,8 +5,12 @@\n XXXX\n+test\n YYYY\n', dmp.patch_toText(patches))
end

function testPatchApply()
  local patches

  dmp.settings{Match_Distance = 1000}
  dmp.settings{Match_Threshold = 0.5}
  dmp.settings{Patch_DeleteThreshold = 0.5}
  -- Null case.
  patches = dmp.patch_make('', '')
  assertEquivalent({'Hello world.', {}},
      {dmp.patch_apply(patches, 'Hello world.')})

  -- Exact match.
  patches = dmp.patch_make('The quick brown fox jumps over the lazy dog.',
      'That quick brown fox jumped over a lazy dog.')
  assertEquivalent(
      {'That quick brown fox jumped over a lazy dog.', {true, true}},
      {dmp.patch_apply(patches, 'The quick brown fox jumps over the lazy dog.')})
  -- Partial match.
  assertEquivalent(
      {'That quick red rabbit jumped over a tired tiger.', {true, true}},
      {dmp.patch_apply(patches, 'The quick red rabbit jumps over the tired tiger.')})
  -- Failed match.
  assertEquivalent(
      {'I am the very model of a modern major general.', {false, false}},
      {dmp.patch_apply(patches, 'I am the very model of a modern major general.')})
  -- Big delete, small change.
  patches = dmp.patch_make(
      'x1234567890123456789012345678901234567890123456789012345678901234567890y',
      'xabcy')
  assertEquivalent({'xabcy', {true, true}}, {dmp.patch_apply(patches,
      'x123456789012345678901234567890-----++++++++++-----'
      .. '123456789012345678901234567890y')})
  -- Big delete, big change 1.
  patches = dmp.patch_make('x1234567890123456789012345678901234567890123456789'
      .. '012345678901234567890y', 'xabcy')
  assertEquivalent({'xabc12345678901234567890'
      .. '---------------++++++++++---------------'
      .. '12345678901234567890y', {false, true}},
      {dmp.patch_apply(patches, 'x12345678901234567890'
      .. '---------------++++++++++---------------'
      .. '12345678901234567890y'
      )})
  -- Big delete, big change 2.
  dmp.settings{Patch_DeleteThreshold = 0.6}
  patches = dmp.patch_make(
        'x1234567890123456789012345678901234567890123456789'
        .. '012345678901234567890y',
        'xabcy'
      )
  assertEquivalent({'xabcy', {true, true}},   {dmp.patch_apply(
        patches,
        'x12345678901234567890---------------++++++++++---------------'
        .. '12345678901234567890y'
      )}
)
  dmp.settings{Patch_DeleteThreshold = 0.5}

  -- Compensate for failed patch.
  dmp.settings{Match_Threshold = 0, Match_Distance = 0}
  patches = dmp.patch_make(
        'abcdefghijklmnopqrstuvwxyz--------------------1234567890',
        'abcXXXXXXXXXXdefghijklmnopqrstuvwxyz--------------------'
        .. '1234567YYYYYYYYYY890'
      )
  assertEquivalent({
        'ABCDEFGHIJKLMNOPQRSTUVWXYZ--------------------1234567YYYYYYYYYY890',
        {false, true}
      }, {dmp.patch_apply(
        patches,
        'ABCDEFGHIJKLMNOPQRSTUVWXYZ--------------------1234567890'
      )})

  dmp.settings{Match_Threshold = 0.5}
  dmp.settings{Match_Distance = 1000}

  -- No side effects.
  patches = dmp.patch_make('', 'test')
  local patchstr = dmp.patch_toText(patches)
  dmp.patch_apply(patches, '')
  assertEquals(patchstr, dmp.patch_toText(patches))
  -- No side effects with major delete.
  patches = dmp.patch_make('The quick brown fox jumps over the lazy dog.',
      'Woof')
  patchstr = dmp.patch_toText(patches)
  dmp.patch_apply(patches, 'The quick brown fox jumps over the lazy dog.')
  assertEquals(patchstr, dmp.patch_toText(patches))
  -- Edge exact match.
  patches = dmp.patch_make('', 'test')
  assertEquivalent({'test', {true}}, {dmp.patch_apply(patches, '')})
  -- Near edge exact match.
  patches = dmp.patch_make('XY', 'XtestY')
  assertEquivalent({'XtestY', {true}}, {dmp.patch_apply(patches, 'XY')})
  -- Edge partial match.
  patches = dmp.patch_make('y', 'y123')
  assertEquivalent({'x123', {true}}, {dmp.patch_apply(patches, 'x')})
end

function runTests()
  local passed = 0
  local failed = 0
  for name, func in pairs(_G) do
    if (type(func) == 'function') and tostring(name):match("^test") then
      local success, message = pcall(func)
      if success then
        print(name .. ' Ok.')
        passed = passed + 1
      else
        print('** ' .. name .. ' FAILED: ' .. tostring(message))
        failed = failed + 1
      end
    end
  end
  print('Tests passed: ' .. passed)
  print('Tests failed: ' .. failed)
  if failed ~= 0 then
    os.exit(1)
  end
end

runTests()

