#!/bin/sh
test_description='Test the pick command'

. ./test-lib.sh

test_expect_success \
	'Attempt pick with uninitialized stack' \
	'
	command_error stg pick foo 2>&1 |
	grep "master: branch not initialized"
	'

test_expect_success \
	'Initialize the StGit repository' \
	'
	stg init &&
	stg new A -m "a" && echo A > a && stg add a && stg refresh &&
	stg new B -m "b" && echo B > b && stg add b && stg refresh &&
	stg branch --clone foo &&
	stg new C -m "c" && echo C > c && stg add c && stg refresh &&
	stg new D-foo -m "d" && echo D > d && stg add d && stg refresh &&
	stg new E -m "e" &&
	echo AA >> a && echo BB >> b && echo CC >> c &&
	stg refresh &&
	stg new AAA -m "aaa" &&
	echo "A" > a && echo "AAA" >> a && echo "AA" >> a && stg refresh &&
	stg branch master
	'

test_expect_success \
	'No pick args' \
	'
	command_error stg pick 2>&1 |
	grep "incorrect number of arguments"
	'

test_expect_success \
	'Pick --name with multiple patches' \
	'
	command_error stg pick --ref-branch foo --name C_and_E C E 2>&1 |
	grep "name can only be specified with one patch"
	'

test_expect_success \
	'Pick remote patch' \
	'
	stg pick foo:C &&
	test "$(echo $(stg series --applied --noprefix))" = "A B C" &&
	test "$(echo $(cat c))" = "C"
	'

test_expect_success \
	'Pick --unapplied remote patch' \
	'
	stg pick --unapplied --ref-branch foo --name D D-foo &&
	test "$(echo $(stg series --applied --noprefix))" = "A B C" &&
	test "$(echo $(stg series --unapplied --noprefix))" = "D"
	'

test_expect_success \
	'Pick --file without --fold' \
	'
	command_error stg pick --file d D 2>&1 |
	grep "file can only be specified with --fold"
	'

test_expect_success \
	'Pick local unapplied patch' \
	'
	stg pick D &&
	test "$(echo $(stg series --applied --noprefix))" = "A B C D-1" &&
	test "$(echo $(stg series --unapplied --noprefix))" = "D"
	'

test_expect_success \
	'Pick --fold --revert local patch' \
	'
	stg pick --fold --revert D &&
	stg refresh && stg clean &&
	test "$(echo $(stg series --applied --noprefix))" = "A B C" &&
	test "$(echo $(stg series --unapplied --noprefix))" = "D"
	'

test_expect_success \
	'Pick --fold without applied patches' \
	'
	stg pop --all &&
	stg pick --fold D &&
	test "$(echo $(stg series --unapplied --noprefix))" = "A B C D" &&
	test "$(echo $(stg status))" = "A d" &&
	stg reset --hard
	'

test_expect_success \
	'Pick --fold --file' \
	'
	stg push --all &&
	stg pick --fold --file a --file c foo:E &&
	test "$(echo $(cat a))" = "A AA" &&
	test "$(echo $(cat b))" = "B" &&
	test "$(echo $(cat c))" = "C CC" &&
	stg reset --hard
	'

test_expect_success \
	'Pick --revert' \
	'
	stg pick --revert C &&
	test "$(stg top)" = "revert-C" &&
	stg show | grep -E "Revert \"c\"" &&
	stg delete revert-C
	'

test_expect_success \
	'Pick with empty result' \
	'
	stg pick -B foo A &&
	stg series -e | grep -E "0> A-1" &&
	stg delete A-1
	'

test_expect_success \
	'Pick --fold with empty result' \
	'
	stg pick --fold -B foo A &&
	test -z "$(stg status)"
	'

test_expect_success \
	'Pick --fold --files empty result' \
	'
	stg pick --fold -B foo A --file c &&
	test -z "$(stg status)"
	'

test_expect_success \
	'Pick --update' \
	'
	stg goto C &&
	stg pick --update -B foo E &&
	test "$(stg status)" = "M  c" &&
	test "$(echo $(cat c))" = "C CC" &&
	stg reset --hard
	'

test_expect_success \
	'Pick --update without applied patches' \
	'
	stg pop -a &&
	command_error stg pick --update -B foo E 2>&1 |
	grep "No patches applied"
	'

test_expect_success \
	'Pick commit with expose' \
	'
	stg branch foo &&
	stg goto C &&
	stg id > C-id &&
	stg commit -a &&
	stg branch master &&
	test_write_lines \
		"c" \
		"" \
		"(imported from commit $(cat C-id))" \
		> C2-expected.txt &&
	test_when_finished rm -f C2-expected.txt C2-message.txt &&
	stg pick --expose --name C2 $(cat C-id) &&
	test "$(stg top)" = "C2" &&
	git show --no-patch --pretty=format:%B > C2-message.txt &&
	test_cmp C2-expected.txt C2-message.txt
	'

test_expect_success \
	'Pick too many commits' \
	'
	command_error stg pick --ref-branch foo $(cat C-id) D-foo 2>&1 |
	grep "Unknown patch name"
	'

test_expect_success \
	'Pick with conflict' \
	'
	rm C-id &&
	stg push A &&
	conflict stg pick foo:AAA 2>&1 |
	grep "1 merge conflict(s)" &&
	test "$(stg top)" = "AAA" &&
	test "$(echo $(stg series -A --noprefix))" = "C2 A AAA" &&
	test "$(echo $(stg status))" = "UU a" &&
	stg reset --hard &&
	stg undo
	'

test_expect_success \
	'Pick --fold with conflict' \
	'
	conflict stg pick --fold --ref-branch=foo AAA 2>&1 |
	grep "Merge conflict in a" &&
	stg reset --hard
	'

test_expect_success \
	'Pick --fold --file with conflict' \
	'
	conflict stg pick --fold --file a -Bfoo AAA 2>&1 |
	grep "AAA does not apply cleanly" &&
	stg reset --hard
	'

test_expect_success \
	'Pick --update with conflict' \
	'
	conflict stg pick --update foo:AAA 2>&1 |
	grep "AAA does not apply cleanly" &&
	stg reset --hard
	'

test_done
