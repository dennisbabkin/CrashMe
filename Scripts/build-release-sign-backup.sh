#!/usr/bin/env bash

#
#  Created by dennisbabkin.com on 7/2/23.
#

# This script builds the production/release binaries as follows:
#
#  - It will build all binaries for release config.
#  - It will then code-sign them.
#  - It will then submit them to the Apple servers for automated notarization.
#    (Notarization usually takes a few minutes to complete.)
#  - It will then create a DMG file for distribution.
#  - Finally it will make a full backup of the source files & of the notarization log.
#
# IMPORTANT: Xcode is required for this build script to work!
#


# This script is a part of the blog post.
# For details check:
#
#      https://dennisbabkin.com/blog/?i=AAA11700#auto_script
#






# Developer ID. Refer to the blog post above for instructions on how to get it:
#   https://dennisbabkin.com/blog/?i=AAA11700#dev_cert_id
#
cs_ident="Z7C8MMR1NR"

# Check add-app-spec-pwd-to-keychain.sh script for details how to set up this Keychain ID,
# or follow this blog post:
#   https://dennisbabkin.com/blog/?i=AAA11700#get_app_pwd_id
#
kch_app_pwd_id_ntrz="AppPwdNotarizID"







color() {
      printf '\033[%sm%s\033[m\n' "$@"
      # usage color "31;5" "string"
      # 0 default
      # 5 blink, 1 strong, 4 underlined
      # fg: 31 red,  32 green, 33 yellow, 34 blue, 35 purple, 36 cyan, 37 white
      # bg: 40 black, 41 red, 44 blue, 45 purple
}
      
echo_error() {
    color '31;1' "$@" >&2
}

echo_success() {
    color '32;1' "$@" >&2
}

echo_accent1() {
    color '34;1' "$@" >&2
}

echo_accent_green() {
    color '102;1' "$@" >&2
}





echo ""
echo "=================================="
echo "Building production release..."
echo "(Internet connection is required...)"
echo ""

# Remember current directory
current_path=$(pwd)

# Get dir where this script is running in
this_dir=$( dirname -- "$0"; )

# Get parent directory
this_dir=$( dirname -- "$this_dir"; )
echo "Working in: $this_dir"

# Get user's documents folder (we will place the backup .DMG there)
doc_fldr=~/Documents




# Define for which OS and for which CPU to build it
build_specs='generic/platform=macOS'



# Define projects to build - use Xcode to copy it from:

# Xcode target names
declare -a arr_targets=("CrashMe")

# Xcode scheme names
declare -a arr_schemes=("CrashMe - Release")

# Xcode project directories
declare -a arr_dirs=(".")









# Make sure the arrays have equal size
if [ ${#arr_targets[@]} != ${#arr_schemes[@]} ] || [ ${#arr_schemes[@]} != ${#arr_dirs[@]} ]; then
    echo_error "[809] Error: Bad build array sizes!"
    echo_error "ABORTING!!!"
    
    cd $current_path
    exit -1
fi




# Get version of the LABService from the source file
# INFO: We'll use it in the names of files later in the build process...
app_ver_line=$(ls -l | grep -E '#define\s+APP_VERSION\s+"(.*)"' "$this_dir/CrashMe/main.cpp")

app_ver=""
regex='"(.+)"'
[[ $app_ver_line =~ $regex ]] &&
  app_ver=${BASH_REMATCH[1]}

if [[ $app_ver ]]; then

    echo "Using build version: $app_ver"

else
    echo_error "[810] FAILED to extract build version."
    echo_error "ABORTING!!!"

    cd $current_path
    exit -1
fi





# Create a temp directory
tmp_bld_dir="$this_dir/build"

output_dir="$tmp_bld_dir/package"

$(rm -rf "$tmp_bld_dir")
$(mkdir -p "$tmp_bld_dir")

$(xattr -w com.apple.xcode.CreatedByBuildSystem true "$tmp_bld_dir")



# Build all projects in a loop
cnt=${#arr_targets[@]}

for (( i=0; i<${cnt}; i++ ));
do
    dir=${arr_dirs[$i]}
    scheme=${arr_schemes[$i]}
    target=${arr_targets[$i]}
  

    echo "Building $target as $scheme in ./$dir"
  
    # Change directory to where the Xcode project is located
    cd "$this_dir/$dir"
    
    echo " Cleaning ..."
    
    # Clean the project first
    xcodebuild clean -target "$target" -scheme "$scheme" -destination "$build_specs" -quiet SYMROOT="$tmp_bld_dir/$target"
    
    # Check result
    exit_code=$?
    if [ $exit_code != 0 ]; then
        echo_error "  [811] FAILED: code=$exit_code"
        
        cd $current_path
        exit -2
    else
        echo_success "  Success!"
    fi
  
  
    echo " Building ..."
    
    # Build it
    xcodebuild -target "$target" -scheme "$scheme" -destination $build_specs -quiet SYMROOT="$tmp_bld_dir/$target"

    # Check result
    exit_code=$?
    if [ $exit_code != 0 ]; then
        echo_error "  [812] FAILED: code=$exit_code"
        
        cd $current_path
        exit -3
    else
        echo_success "  Success!"
    fi

done




echo ""


# Copy our Mach-O binary into the app bundle template

# ditto source destination
ditto "$this_dir/Scripts/AppBundleTemplate/CrashMe app.app" "$tmp_bld_dir/$target/Release/CrashMe.app"

# Check the result
exit_code=$?
if [ $exit_code != 0 ]; then

    echo_error "  [411] FAILED: code=$exit_code"
    
    cd $current_path
    exit -3
fi


# ditto source destination
ditto "$tmp_bld_dir/$target/Release/CrashMe" "$tmp_bld_dir/$target/Release/CrashMe.app/Contents/MacOS/CrashMe"

echo "Creating app bundle: "


# Check the result
exit_code=$?
if [ $exit_code == 0 ]; then

    echo_success "  Success!"

else
    echo_error "  [412] FAILED: code=$exit_code"
    
    cd $current_path
    exit -3
fi







# Define which binaries to code-sign

# Sign these in reverse order (for .app bundles)
declare -a arr_bin_paths=(
    "$tmp_bld_dir/CrashMe/Release/CrashMe"
    "$tmp_bld_dir/CrashMe/Release/CrashMe.app/Contents/MacOS/CrashMe"
    "$tmp_bld_dir/CrashMe/Release/CrashMe.app"
    )

declare -a arr_idents=(
    "com.dennisbabkin.CrashMe"
    "com.dennisbabkin.CrashMe.mach_o"
    "com.dennisbabkin.CrashMe.app"
    )

# Leave blank if no entitlement
declare -a arr_entitlements=(
    ""
    ""
    "$this_dir/Scripts/CrashMe.entitlements"
    )




# Make sure the arrays have equal size
if [ ${#arr_bin_paths[@]} != ${#arr_idents[@]} ] || [ ${#arr_bin_paths[@]} != ${#arr_entitlements[@]} ]; then
    echo_error "[814] Error: Bad build array sizes!"
    echo_error "ABORTING!!!"
    
    cd $current_path
    exit -1
fi



echo "-------------------------------"


# Code-sign all binaries
cnt=${#arr_bin_paths[@]}

for (( i=0; i<${cnt}; i++ ));
do
    bin_path=${arr_bin_paths[$i]}
    fnm="${bin_path##*/}"
    
    ident=${arr_idents[$i]}
    
    ent=${arr_entitlements[$i]}
    
    
    echo ""
    echo "Code-signing $fnm:"
  
  
    if [[ $ent ]]; then
        codesign -s "$cs_ident" -f --timestamp -o runtime -i "$ident" --entitlements "$ent" "$bin_path"
    else
        codesign -s "$cs_ident" -f --timestamp -o runtime -i "$ident" "$bin_path"
    fi

    # Check result
    exit_code=$?
    if [ $exit_code != 0 ]; then
        echo_error "  [813] FAILED: code=$exit_code"
        
        cd $current_path
        exit -3
    else
        echo_success "  Success!"
    fi


    # SECURITY CHECK:
    #
    #  Get entitlements from the signed binary & make sure that attaching to it with debugger is disabled
    #
    rz_ent=$(codesign -d --entitlements - --xml "$bin_path" | grep -E "com.apple.security.get-task-allow")
    if [[ $rz_ent ]]; then
        echo_error "  [815] FAILED: get-task-allow is present in binary!"
        
        cd $current_path
        exit -3
    fi

    

done






# Temp folder for .ZIP'ing
tmp_wrk_dir="$tmp_bld_dir/_tmp_bld"
tmp_zip_dir="$tmp_wrk_dir/NotarizationFile"

# remove old dir, if it's there & create a new one
$(rm -rf "$tmp_wrk_dir")
$(mkdir -p "$tmp_wrk_dir")

cd $tmp_wrk_dir

# remove old dir, if it's there & create a new one
$(rm -rf "$tmp_zip_dir")
$(mkdir -p "$tmp_zip_dir")





echo ""



# Files to notarize
# INFO: Do not notarize executables that were included in the installer .pkg,
#       as the notarization service will be able to extract those from it and notarize them.
#       Otherwise, if we specify them here, it will just take longer...

declare -a arr_bins_2_ntrz=(
    "$tmp_bld_dir/CrashMe/Release/CrashMe.app"
    )


echo "Creating .ZIP archive for notarization..."

cnt=${#arr_bins_2_ntrz[@]}

for (( i=0; i<${cnt}; i++ ));
do
    bin_path=${arr_bins_2_ntrz[$i]}

    flnm=${bin_path##*/}
    dest="$tmp_zip_dir/$flnm"

    # Make a copy
    ditto "$bin_path" "$dest"

    # Check result
    exit_code=$?
    if [ $exit_code != 0 ]; then
        echo_error "  [816] FAILED: code=$exit_code"

        $(rm -rf "$tmp_wrk_dir")
        
        cd $current_path
        exit -3
    fi

done


# Create a .ZIP file
zip_file_path="$tmp_wrk_dir/NotarizationFile.zip"
ditto -c -k --keepParent "$tmp_zip_dir" "$zip_file_path"

# Check result
exit_code=$?
if [ $exit_code != 0 ]; then
    echo_error "  [817] FAILED to zip $tmp_zip_dir: code=$exit_code"

    $(rm -rf "$tmp_wrk_dir")
    
    cd $current_path
    exit -3
fi



echo_success "  Success!"

echo ""



echo "Uploading .ZIP archive for notarization to Apple and waiting for result..."
echo "(Please wait ... it may take a few minutes.)"

# Upload the .ZIP archive to Apple servers for notarization & wait for result
res_ntrz=$(xcrun notarytool submit "$zip_file_path" --keychain-profile "$kch_app_pwd_id_ntrz" --wait)

exit_code=$?
if [ $exit_code != 0 ]; then
    echo_error "  [818] ERROR: Notarization call failed: code=$exit_code"

    $(rm -rf "$tmp_wrk_dir")

    cd $current_path
    exit -3
fi



#    Conducting pre-submission checks for NotizationFile.zip and initiating connection to the Apple notary service...
#    Submission ID received
#      id: 741ce82f-de27-48d0-813d-fbe2343c8e1c
#    Upload progress: 100.00% (720 KB of 720 KB)
#    Successfully uploaded file
#      id: 741ce82f-de27-48d0-813d-fbe2343c8e1c
#      path: /Users/user/Documents/NotizationFile.zip
#    Waiting for processing to complete.
#    Current status: Accepted.......
#    Processing complete
#      id: 741ce82f-de27-48d0-813d-fbe2343c8e1c
#      status: Accepted



#    Conducting pre-submission checks for NotizationFile.zip and initiating connection to the Apple notary service...
#    Submission ID received
#      id: 741ce82f-de27-48d0-813d-fbe2343c8e1c
#    Upload progress: 100.00% (1.26 MB of 1.26 MB)
#    Successfully uploaded file
#      id: 741ce82f-de27-48d0-813d-fbe2343c8e1c
#      path: /Users/user/Documents/NotizationFile.zip
#    Waiting for processing to complete.
#    Current status: Invalid.......
#    Processing complete
#      id: 741ce82f-de27-48d0-813d-fbe2343c8e1c
#      status: Invalid


# To see regex syntax for ZSH use:
#   man tr

# Get status
ntrz_status=""
regex='status:[[:blank:]]*([[:alnum:]]+)$'
[[ $res_ntrz =~ $regex ]] &&
  ntrz_status=${BASH_REMATCH[1]}

# Get submission ID
ntrz_id=""
regex='id:[[:blank:]]*([[:xdigit:]-]+)'
[[ $res_ntrz =~ $regex ]] &&
  ntrz_id=${BASH_REMATCH[1]}


echo "-------------------------------"
echo ""

if [[ $ntrz_status ]] && [[ $ntrz_id ]]; then

    echo "Received notarization result:"
    echo "Status: $ntrz_status"
    echo "ID: $ntrz_id"

else
    echo_error "[821] FAILED to parse result from the Apple notarization server:"
    echo ""
    echo "$res_ntrz"

    $(rm -rf "$tmp_wrk_dir")

    cd $current_path
    exit -1
fi



echo "-------------------------------"


# set nocasematch option
shopt -s nocasematch
if [[ $ntrz_status != "accepted" ]]; then

    # unset nocasematch option
    shopt -u nocasematch

    echo_error "FAILED to notarize!"
    echo "Retrieving notarization log..."

    # To check status of submission:
    #
    #  xcrun notarytool log <guid> --keychain-profile "AppPwdNotarizID"

    # Get the log file
    log_ntrz=$(xcrun notarytool log "$ntrz_id" --keychain-profile "$kch_app_pwd_id_ntrz")

    echo "---------------------------------"
    echo "$log_ntrz"

    echo_error "[822] ABORTING after last failure!"

    $(rm -rf "$tmp_wrk_dir")

    cd $current_path
    exit -1
fi

# unset nocasematch option
shopt -u nocasematch


echo_success "Notarization success!"
echo ""





dmg_backup_file_name="Backup - CrashMe $app_ver.dmg"

# Save notarization log
ntrz_log_fnm="Notarization Log, ID $ntrz_id.txt"
echo "Saving notarization log in:"
echo "'$ntrz_log_fnm'"
echo "(You can find it in the '$dmg_backup_file_name' file.)"

ntrz_log_path="$tmp_zip_dir/$ntrz_log_fnm"

r=$(xcrun notarytool log "$ntrz_id" --keychain-profile "$kch_app_pwd_id_ntrz" "$ntrz_log_path")

# Check result
exit_code=$?
if [ $exit_code != 0 ]; then
    echo_error "  [825] FAILED: code=$exit_code"

    $(rm -rf "$tmp_wrk_dir")

    cd $current_path
    exit -3
fi

echo ""



# App bundles to staple
# NOTE: that we won't be able to staple stand-alone Mach-O executables!
declare -a arr_2staple=(
                        "$tmp_bld_dir/CrashMe/Release/CrashMe.app"
                        )

# To staple the ticket:
#
#  xcrun stapler staple -q "<name>.app"


cnt=${#arr_2staple[@]}

for (( i=0; i<${cnt}; i++ ));
do
    bin_path=${arr_2staple[$i]}
    fnm="${bin_path##*/}"

    echo "Stapling ticket to: $fnm ..."

    xcrun stapler staple -q "$bin_path"


    # Check result
    exit_code=$?
    if [ $exit_code != 0 ]; then
        echo_error "  [824] FAILED: code=$exit_code"

        $(rm -rf "$tmp_wrk_dir")

        cd $current_path
        exit -3
    else
        echo_success "  Success!"
    fi


done




# ****************************************************************************
# ****************************************************************************
# ****************************************************************************
# ****************************************************************************




# Create a .DMG file for distribution
echo "-------------------------------"
echo ""

echo "Creating a .DMG disk image for distribution..."

dmg_dir="$output_dir/CrashMe Package $app_ver"

# Create a temp directory
$(mkdir -p "$dmg_dir")

# Check result
exit_code=$?
if [ $exit_code != 0 ]; then
    echo_error "  [829] FAILED to create temp dir: code=$exit_code"
    
    $(rm -rf "$tmp_wrk_dir")
    
    cd $current_path
    exit -2
fi





# Copy our app bundle into it
orig_app="$tmp_bld_dir/CrashMe/Release/CrashMe.app"
flnm=${orig_app##*/}
dmg_path="$dmg_dir/$flnm"

# ditto source destination
ditto "$orig_app" "$dmg_path"


# Check result
exit_code=$?
if [ $exit_code != 0 ]; then
    echo_error "  [831] FAILED to copy: code=$exit_code"
    
    $(rm -rf "$tmp_wrk_dir")
    
    cd $current_path
    exit -2
fi







# Create .dmg
dmg_final_file="$output_dir/CrashMe Package $app_ver.dmg"
hdiutil create -volname "CrashMe Package $app_ver" -srcfolder "$dmg_dir" -ov -format UDZO "$dmg_final_file"


# Check result
exit_code=$?
if [ $exit_code != 0 ]; then
    echo_error "  [832] FAILED to create .DMG: code=$exit_code"
    
    $(rm -rf "$tmp_wrk_dir")
    
    cd $current_path
    exit -2
fi


# Output result
echo "*** Final distribution .DMG file is ready as:"
resolved=$(readlink -f "$dmg_final_file")
echo_accent1 "$resolved"

$(rm -rf "$dmg_dir")







###################################################################

# Copy all release build files, symbols and all source projects and compress them in a .dmg file
echo "-------------------------------"
echo ""


dmg_dir="$doc_fldr/Backup - CrashMe $app_ver"

# remove old dir, if it's there
$(rm -rf "$dmg_dir")

# Create a temp directory
$(mkdir -p "$dmg_dir")


# Copy the notarization log

#cp -r source destination
cp -r "$ntrz_log_path" "$dmg_dir/$ntrz_log_fnm"

# Check result
exit_code=$?
if [ $exit_code != 0 ]; then
    echo_error "  [335] FAILED to copy notarization log: code=$exit_code"
    
    $(rm -rf "$tmp_wrk_dir")
    
    cd $current_path
    exit -2
fi


# Remove temp build folder
$(rm -rf "$tmp_wrk_dir")



# Copy the entire source code project directory
echo "Copying the source directory for backup purposes..."

#cp -r source destination
cp -r "$this_dir" "$dmg_dir"

# Check result
exit_code=$?
if [ $exit_code != 0 ]; then
    echo_error "  [835] FAILED to copy LABServiceMac directory: code=$exit_code"
    
    $(rm -rf "$tmp_wrk_dir")
    
    cd $current_path
    exit -2
fi




# Create .dmg
echo "Creating backup .DMG..."

dmg_backup_file="$doc_fldr/$dmg_backup_file_name"
hdiutil create -volname "Backup CrashMe $app_ver" -srcfolder "$dmg_dir" -ov -format UDZO "$dmg_backup_file"


# Check result
exit_code=$?
if [ $exit_code != 0 ]; then
    echo_error "  [839] FAILED to create backup .DMG: code=$exit_code"
    
    $(rm -rf "$tmp_wrk_dir")
    
    cd $current_path
    exit -2
fi



# Remove temp files
$(rm -rf "$dmg_dir")
$(rm -rf "$tmp_wrk_dir")



# Output result
echo "*** Final backup .DMG file is ready as:"
resolved=$(readlink -f "$dmg_backup_file")
echo_accent1 "$resolved"





# All done
echo ""
echo_accent_green "*** ALL DONE! ***"

cd $current_path
echo "=================================="
(exit 0);
