#!/bin/sh
# shellcheck disable=SC2016

test_description='Test "stg pop --spill"'

. ./test-lib.sh

test_expect_success 'Initialize the StGit repository and create a patch and add some files' '
    stg init &&
    echo expected*.txt >> .git/info/exclude &&
    echo patches.txt >> .git/info/exclude &&
    echo status.txt >> .git/info/exclude &&
    echo message.txt >> .git/info/exclude &&
    stg new test-patch -m "Test Patch" &&
    echo "local 0" >> patch0.txt &&
    git add -A
'

test_expect_success 'Save current patch message to a file' '
    stg edit --save-template=- >> expected-message.txt
'

cat > expected-patches.txt <<EOF
EOF
cat > expected-status.txt <<EOF
A  patch0.txt
EOF
test_expect_success 'Check file status' '
    stg status > status.txt &&
    test_cmp expected-status.txt status.txt &&
    stg patches patch0.txt > patches.txt &&
    test_cmp expected-patches.txt patches.txt
'

cat > expected-patches.txt <<EOF
test-patch
EOF
cat > expected-status.txt <<EOF
EOF
test_expect_success 'Add files to the patch' '
    git add -A && stg refresh &&
    stg status > status.txt &&
    test_cmp expected-status.txt status.txt &&
    stg patches patch0.txt > patches.txt &&
    test_cmp expected-patches.txt patches.txt
'

test_expect_success 'Spill the topmost patch' '
    stg refresh --spill
'

test_expect_success 'Check that topmost patch description did not change' '
    test "$(echo $(stg top))" = "test-patch" &&
    stg edit --save-template=- >> message.txt &&
    test_cmp expected-message.txt message.txt
'

cat > expected-patches.txt <<EOF
EOF
cat > expected-status.txt <<EOF
A  patch0.txt
EOF
test_expect_success 'Check that added file is no longer present in patches and changes are now in index' '
    stg status > status.txt &&
    test_cmp expected-status.txt status.txt
    stg patches patch0.txt > patches.txt &&
    test_cmp expected-patches.txt patches.txt
'

test_done
