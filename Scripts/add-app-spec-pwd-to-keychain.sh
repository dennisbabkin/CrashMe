#!/usr/bin/env bash

# This script adds your app-specific password to the local Keychain
# (It has to be run only once if the result is a success.)
#
#  Created by dennisbabkin.com on 7/2/23.
#

# This script is a part of the blog post.
# For details check:
#
#      https://dennisbabkin.com/blog/?i=AAA11700#notarize
#




# Your secret app-specific password to store in the Keychain.
# IMPORTANT: Make sure to remove it from this script after you run it!!!
#
kch_app_pwd_ntrz="gmoe-zjve-ouua-wexy"

# ID to store the password under in the Keychain (may be known publicly)
#
kch_app_pwd_id_ntrz="AppPwdNotarizID"

# Apple ID for the dev account (usually an email address)
#
cs_ident="someone@example.com"

# WWDRTeamID value
#
# To get the WWDRTeamID run the following in the terminal
# with 'cs_ident' and 'kch_app_pwd_ntrz' from above:
#
#  xcrun altool --list-providers -u <cs_ident> -p "<kch_app_pwd_ntrz>"
#
wwdr_team_id="Z4J0MVV4PQ"



xcrun notarytool store-credentials "$kch_app_pwd_id_ntrz" --apple-id "$cs_ident" --team-id "$wwdr_team_id" --password "$kch_app_pwd_ntrz"


# Check result
exit_code=$?
if [ $exit_code != 0 ]; then
    echo "FAILED: Did not add password to the Keychain, error code=$exit_code"
    
    exit $exit_code
else
    echo "Success adding password to the Keychain!"
    echo "IMPORTANT: Make sure to remove your plaintext password from this script!!!"
    
    exit 0
fi
