#!/bin/bash

timeString=`date +%m-%d\ %H%M`
userDir=$(cd ~; pwd)
currentDir=$(pwd)
outputDir="${currentDir}/../Archive-xcodebuild/${timeString}"

##################################处理参数######################################

# 模拟器支持架构
SIMULATOR_ARCHS="i386 x86_64"
#
# 真机支持架构 
IPHONEOS_ARCHS="arm64 armv7"

ARCH_ARMV7="armv7 arm64"


SHOULDBUILDDSYM=""

# 是否生成DSYM 文件
DSYMOPTION="YES"

SWIFT_LEVEL_FAST="-Owholemodule"
SWIFT_LEVEL_MIDDLE="-O"
SWIFT_LEVEL_NONE="-Onone"

SWIFT_LEVEL_OPTION=$SWIFT_LEVEL_MIDDLE

SDK_IPHONEOS="iphoneos"

############默认的架构###########
TARTGET_ARCHS=$IPHONEOS_ARCHS

ENABLE_BITCODE="NO"

############################具体参数处理#####################


###########################提示语#####################
function useage() {
                echo "                     [-e # <dev,rel #>]"
                echo "                     [-o 日志输出路径默认为Desktop/Archive-xcodebuild]"
}

index=0;
lastpara="!"
#######################循环参数############################
while getopts ":'e':o:" OPTNAME
do

 case $OPTNAME in
        #处理环境 是否是dev 环境
        "e" )
            if [[ $OPTARG == "dev" ]]; then
                debugArchiveSetting
            fi
            if [[ $2 == "rel" ]]; then
                echo "++++++++++++$2"
                TARTGET_ARCHS=$IPHONEOS_ARCHS              
            fi
            ;;
            ###########################处理输出路径
      "o")
            if [[ "$OPTARG" != "" ]]
            then
            outputDir="$OPTARG/"
            fi
            ;;   
      "?")  
      echo "无效参数: -$OPTARG"   
      useage
      exit -1
      ;;  
     *)
        useage
        exit -1
        ;;    
    esac
done

####################################################################################

function debugArchiveSetting(){
             TARTGET_ARCHS=$ARCH_ARMV7
                DSYMOPTION="YES"
                SWIFT_LEVEL_OPTION=$SWIFT_LEVEL_NONE
}

function openLab(){
   
    LABFILE="./TT/TT/lab.plist"
    # REPLACE=`sed -i -e 's|false|true|' ${LABFILE} `
    echo "-------"
    REPLACE=`sed -i '' '/enableLab/{ n; s|false|true|; }' ${LABFILE} `
    # REPLACE=`sed -i '/enableLab/{ n; s|false|true|; }' ${LABFILE} `
    if [ "$REPLACE" = "" ];
     then        
        echo "已打开调试模式"
    else
        echo "打开调试模式失败 $REPLACE"         
     fi

}

function closeLab {
    LABFILE="./TT/TT/lab.plist"
    LABCONTENT=`cat ${LABFILE}`    
     REPLACE=`sed -i '' '/enableLab/{ n; s|true|false|; }' ${LABFILE} `

    if [ "$REPLACE" = "" ];
     then        
        echo "已关闭调试模式"
    else
        echo "关闭调试模式失败 $REPLACE"         
     fi

}

function buildIncrease {
    TT_INFO="./TT/TT/Info.plist"
    buildnum=$(/usr/libexec/PlistBuddy -c "Print CFBundleVersion" "${TT_INFO}")
    if [[ "${buildnum}" == "" ]]; 
     then
        echo "No build number in $TT_INFO"
        exit 2
    fi

    buildnum=$(expr $buildnum + 1)
    /usr/libexec/Plistbuddy -c "Set CFBundleVersion $buildnum" "${TT_INFO}"
    echo "Bumped TT build number to $buildnum"

    TTWidget_INFO="./TT/TTWidget/Info.plist"
    buildnum=$(/usr/libexec/PlistBuddy -c "Print CFBundleVersion" "${TTWidget_INFO}")
    if [[ "${buildnum}" == "" ]]; 
     then
        echo "No build number in $TTWidget_INFO"
        exit 2
    fi

    buildnum=$(expr $buildnum + 1)
    /usr/libexec/Plistbuddy -c "Set CFBundleVersion $buildnum" "${TTWidget_INFO}"
    echo "Bumped TTWidget build number to $buildnum"
}

####################################################################################


 if [[ ! -d "$outputDir" ]]
                then
                mkdir -p "$outputDir"
                if [[ "$?" != 0 ]]
                then
                    errmsg "Fail to create output directory. Task is terminated..."
                exit -1
                fi
            fi

function errmsg()
{
    msg="$1"
    echo -e "\033[31m$msg\033[0m"
}



uuid=$(uuidgen)

projDir=$(cd `dirname $0`; pwd) # project abs Dir
TT_projectConfig="${projDir}/TT/TT.xcodeproj/project.pbxproj"
TT_InfoPlist="${projDir}/TT/TT/Info.plist"
TT_App_Entitlements="${projDir}/TT/TT/TT.entitlements"
TT_Widget_Entitlements="${projDir}/TT/TTWidget/TTWidget.entitlements"
TT_Widget_Constants="${projDir}/TT/TTWidget/TTWidgetConst.h"
zegoAVKitDir="${projDir}/TTService/TTService/3rd/ZegoKit/"
zegoAVKit="${projDir}/TTService/TTService/3rd/ZegoKit/ZegoLiveRoom.framework"
zegoAVKit_BAK="${projDir}/TTService/TTService/3rd/ZegoKit/ZegoLiveRoom@.framework"
zegoAVKit_verArchive="${projDir}/TTService/TTService/3rd/ZegoKit/ZegoLiveRoom_Archive/ZegoLiveRoom.framework"
TT_PCH="${projDir}/TT/TT/TT_Prefix.pch"

workspace="TT.xcworkspace"
bundle_id_app="com.yiyou.tt"
bundle_id_widget="com.yiyou.tt.TTWidget"
bundle_id_app_ENT="com.yiyou.enterprise.tt"
bundle_id_widget_ENT="com.yiyou.enterprise.tt.TTWidget"
bundle_display_name="<string>TT<\/string>"
bundle_display_name_ENT="<string>$timeString<\/string>"

AppGroup="group.guildrealtimevoice.tt.com"
AppGroup_ENT="group.com.yiyou.enterprise.tt"
Target_Name="TT"

team="KS98J4RYQ2"
team_ENT="R8CD7VW2A4"

log_path="${outputDir}/$uuid.log"
configuration="Release"
scheme="TT"
scheme_ENT="TT_Enterprise"
exportOptions=""

function createEnterpriseExportOptionsPlist()
{
    echo "<?xml version=\"1.0\" encoding=\"UTF-8\"?>" > "$1"
    echo "<!DOCTYPE plist PUBLIC \"-//Apple//DTD PLIST 1.0//EN\" \"http://www.apple.com/DTDs/PropertyList-1.0.dtd\">" >> "$1"
    echo "<plist version=\"1.0\">" >> "$1"
    echo "<dict>" >> "$1"
    echo "  <key>method</key>" >> "$1"
    echo "  <string>enterprise</string>" >> "$1"
    echo "</dict>" >> "$1"
    echo "</plist>" >> "$1"
}

function createAdHocExportOptionsPlist()
{
    echo "<?xml version=\"1.0\" encoding=\"UTF-8\"?>" > "$1"
    echo "<!DOCTYPE plist PUBLIC \"-//Apple//DTD PLIST 1.0//EN\" \"http://www.apple.com/DTDs/PropertyList-1.0.dtd\">" >> "$1"
    echo "<plist version=\"1.0\">" >> "$1"
    echo "<dict>" >> "$1"
    echo "  <key>method</key>" >> "$1"
    echo "  <string>ad-hoc</string>" >> "$1"
    echo "</dict>" >> "$1"
    echo "</plist>" >> "$1"
}

function createAppStoreExportOptionsPlist()
{
    echo "<?xml version=\"1.0\" encoding=\"UTF-8\"?>" > "$1"
    echo "<!DOCTYPE plist PUBLIC \"-//Apple//DTD PLIST 1.0//EN\" \"http://www.apple.com/DTDs/PropertyList-1.0.dtd\">" >> "$1"
    echo "<plist version=\"1.0\">" >> "$1"
    echo "<dict>" >> "$1"
    echo "  <key>method</key>" >> "$1"
    echo "  <string>app-store</string>" >> "$1"
    echo "  <key>uploadBitcode</key>" >> "$1"
    echo "  <false/>" >> "$1"
    echo "  <key>uploadSymbols</key>" >> "$1"
    echo "  <true/>" >> "$1"
    echo "</dict>" >> "$1"
    echo "</plist>" >> "$1"
}

Log_m_path="${projDir}/TTFoundation/TTFoundation/Log/Log.m"
oZegoLogFileCount="static UInt32 const kMaxZegoLogFileCount = 10;"
oLogFileMaxSize="static UInt32 const kLogFileToUploadMaxSize = (1024\*1024\*10);"
nZegoLogFileCount="static UInt32 const kMaxZegoLogFileCount = 50;"
nLogFileMaxSize="static UInt32 const kLogFileToUploadMaxSize = (1024\*1024\*50);"

function resetProjectConfig()
{
    sed -i "" "s/$bundle_display_name_ENT/$bundle_display_name/g" "$TT_InfoPlist"
    sed -i "" "s/$bundle_id_app_ENT/$bundle_id_app/g" "$TT_projectConfig"
    sed -i "" "s/$bundle_id_widget_ENT/$bundle_id_widget/g" "$TT_projectConfig"
    sed -i "" "s/$team_ENT/$team/g" "$TT_projectConfig"
    sed -i "" "s/$AppGroup_ENT/$AppGroup/g" "$TT_App_Entitlements" "$TT_Widget_Entitlements" "$TT_Widget_Constants"

    sed -i "" "s/$nZegoLogFileCount/$oZegoLogFileCount/g" "$Log_m_path"
    sed -i "" "s/$nLogFileMaxSize/$oLogFileMaxSize/g" "$Log_m_path"
}


function setEnterpriseProjectConfig()
{
    sed -i "" "s/$bundle_display_name/$bundle_display_name_ENT/g" "$TT_InfoPlist"
    sed -i "" "s/$bundle_id_app/$bundle_id_app_ENT/g" "$TT_projectConfig"
    sed -i "" "s/$bundle_id_widget/$bundle_id_widget_ENT/g" "$TT_projectConfig"
    sed -i "" "s/$team/$team_ENT/g" "$TT_projectConfig"
    sed -i "" "s/$AppGroup/$AppGroup_ENT/g" "$TT_App_Entitlements" "$TT_Widget_Entitlements" "$TT_Widget_Constants"

    sed -i "" "s/$oZegoLogFileCount/$nZegoLogFileCount/g" "$Log_m_path"
    sed -i "" "s/$oLogFileMaxSize/$nLogFileMaxSize/g" "$Log_m_path"
}



function okmsg()
{
    msg="$1"
    echo -e "\033[32m$msg\033[0m"
}



function showInfo()
{
    msg="$1"
    echo -e "\033[33m$msg\033[0m"
}

function reset2Development()
{
    rm -r -f "$zegoAVKit"
    mv -f "$zegoAVKit_BAK" "$zegoAVKit"
    resetProjectConfig
}

function showProcessingHint()
{
    msg="$1"
    flag=0
    while true
    do
        temp="$msg"
        for((i=0;i<flag;++i));do temp="$temp."; done
        echo -n -e "\r\033[K\033[0m"
        echo -n -e "$temp"
        let flag=(flag+1)%9
        sleep 1
    done
}

function get_last_modified {
    echo -e -n "$(git show --format="%ci %cr" $1 | head -n 1 | cut -d ' ' -f4-6)"
}

function check_git_dir {
    local IS_GIT_DIR=$(git rev-parse --is-inside-work-tree)
    if [ ! "$IS_GIT_DIR" == "true" ]; then
        errmsg "不是有效的git目录"
    else
        REMOTE=$1
        if [ "$REMOTE" == "" ]; then
            REMOTE=origin
        fi

        if [ "$(git remote | grep $REMOTE)" == "" ]; then
            errmsg "remote '$REMOTE' does not exist"
            exit 1
        fi

        git remote update $REMOTE > /dev/null 2>&1

        REMOTE_URL=$(git config --get remote.$REMOTE.url)
        BRANCH=$(git rev-parse --abbrev-ref HEAD)

        LAST_REMOTE_COMMIT=""
        REMOTE_LAST_MODIFIED=""
        REMOTE_BRANCH_EXISTS=false
        if [ ! "$(git branch -r  | grep $GROUP/$BRANCH)" == "" ]; then
            REMOTE_BRANCH_EXISTS=true
            LAST_REMOTE_COMMIT=$(git rev-parse $REMOTE/$BRANCH)
            REMOTE_LAST_MODIFIED=$(get_last_modified $REMOTE/$BRANCH)
        fi

        LAST_LOCAL_COMMIT=$(git --no-pager log --max-count=1 | head -n1 | cut -d ' ' -f2)
        LOCAL_LAST_MODIFIED=$(get_last_modified $BRANCH)

        INSYNC=false
        if [ "$LAST_LOCAL_COMMIT" == "$LAST_REMOTE_COMMIT" ]; then
            INSYNC=true
        fi

        while [ ! -d .git ] && [ ! `pwd` = "/" ]; do cd ..; done
            WORKING_COPY_ROOT_PATH=$(pwd)

            showInfo "Working Copy Root Path: $WORKING_COPY_ROOT_PATH"
            showInfo "                Remote: $REMOTE"
            showInfo "            Remote URL: $REMOTE_URL"
            showInfo "                Branch: $BRANCH"
            showInfo "     Last Local Commit: $LAST_LOCAL_COMMIT ($LOCAL_LAST_MODIFIED)"
        if [ "$REMOTE_BRANCH_EXISTS" == "true" ]; then
            showInfo "    Last Remote Commit: $LAST_REMOTE_COMMIT ($REMOTE_LAST_MODIFIED)"
            showInfo "          Synchronized: $INSYNC"
        else
            showInfo "    Last Remote Commit: -- no remote branch --"
            showInfo "          Synchronized: -- no remote branch --"
        fi
    fi
}


#*****************************************这里修改xcode文件的某个配置的值*************************************#
filepath=TT/TT.xcodeproj/project.pbxproj
functhParam(){
    orgin=$(grep -i -n $1 $filepath | head -n 1 | awk -F ':' '{print $1}')
    count=$(grep -i -A 200 $1 $filepath | grep -i -n 'ENABLE_BITCODE' | head -n 1 |awk -F ':' '{print $1}')
    let line=$orgin+count-1
    echo $line
    sed -i '' $line"s/^.*/$2/g" $filepath
}


#*********************************************************************************************************#


clear
echo "===================================================================================================="
echo "======================================== Start logging ========================================" > "$log_path"

check_git_dir

echo "----------------------------------------------------------------------"
CURRENTXCODE=`xcode-select -print-path`
echo ""
echo "当前编译xcode路径为 ${CURRENTXCODE}"
echo "请检查是否为期望值"
echo "使用 ‘sudo xcode-select -switch /Applications/Xcode.app’ 修改路径"
echo ""

echo "----------------------------------------------------------------------"
echo "" >> "$log_path"

echo "Type in option:"
echo "1. TT (ad-hoc)"
echo "2. TT (Upload to AppStore)"
echo "3. TT_Enterprise"

echo -e "Your option: \c"
read
showInfo ">>>>Task UUID: $uuid"
echo "----------------------------------------------------------------------"

op="$REPLY"

echo "选择TARGET_NAME"
echo "1. TT"
echo "2. TTPAY"
echo "3. TT BUILD+1"

echo -e "Your option: \c"
read
echo "----------------------------------------------------------------------"
TOP="$REPLY"
if [[ "$TOP" == 1 ]]; then
    scheme="TT"
    #statements
fi
if [[ "$TOP" == 2 ]]; then
    scheme="TTPay"

fi


if [[ "$TOP" == 3 ]]; then
    scheme="TT"
    buildIncrease
fi

echo "打包TARGET ${Target_Name}"
echo "----------------------------------------------------------------------"

if [[ "$op" == 1 ]] || [[ "$op" == 2 ]]
then
    if [[ ! -f "$TT_projectConfig" ]] || [[ ! -f "$TT_App_Entitlements" ]] || [[ ! -f "$TT_Widget_Entitlements" ]] || [[ ! -f "$TT_Widget_Constants" ]]
    then
        errmsg "Can not find project config. Task is terminated..."
        exit -1
    else
        resetProjectConfig
        if [[ $op == 1 ]]
        then
            exportOptions="/tmp/AdHocExportOptions.plist"
            createAdHocExportOptionsPlist "$exportOptions"
            debugArchiveSetting
            openLab
        else
#*****************************************这里修改BitCode的值*************************************#
	echo "这里是正式包 打开 bitecode "
    ENABLE_BITCODE="YES"
	functhParam "^.*4E3860E11B8C3D6600131962.*=" '                ENABLE_BITCODE = "YES";'
	functhParam "^.*6E1BCCEE1C328EFD006C4951.*=" '                ENABLE_BITCODE = "YES";'
#************************************************************************************************#
            exportOptions="/tmp/AppStoreExportOptions.plist"
            createAppStoreExportOptionsPlist "$exportOptions"
            closeLab
        fi
    fi
elif [[ "$op" == 3 ]]
then
    if [[ ! -f "$TT_projectConfig" ]] || [[ ! -f "$TT_App_Entitlements" ]] || [[ ! -f "$TT_Widget_Entitlements" ]] || [[ ! -f "$TT_Widget_Constants" ]]
    then
        errmsg "Can not find project config. Task is terminated..."
        exit -1
    else
        setEnterpriseProjectConfig
        scheme="$scheme_ENT"
        exportOptions="/tmp/EnterpriseExportOptions.plist"
        createEnterpriseExportOptionsPlist "$exportOptions"
        openLab
    fi
else
    errmsg "Wrong option. Task is terminated..."
    echo "===================================================================================================="
    echo
    exit -1
fi

#disable ENABLE_LAB
if [[ "$op" == 2 ]]
then
    sed -i "" 's/^#define ENABLE_LAB/\/\/#define ENABLE_LAB/' ./TT/TT/TT_Prefix.pch
fi

# replace with release version SDK
[[ ! -d "$zegoAVKit_BAK" ]] && mv -f "$zegoAVKit" "$zegoAVKit_BAK"
[[ -d "$zegoAVKit" ]] && rm -r -f "$zegoAVKit"
cp -R "$zegoAVKit_verArchive" "$zegoAVKitDir"

# showProcessingHint "Cleaning workspace." &
# BG_PID="$!";trap "(kill -9 $BG_PID &);echo;reset2Development;exit -1" INT

#echo "======================================== Log for cleaning ========================================" >> "$log_path"

#xcodebuild -workspace "$workspace" -scheme "$scheme" clean >> "$log_path" 2>&1   # 标准错误->标准输出，使两者在同一个文件里面

#kill "$BG_PID";wait "$BG_PID" 2>"/dev/null"    #http://stackoverflow.com/questions/81520/how-to-suppress-terminated-message-after-killing-in-bash
#echo;okmsg "Cleaned."

archivePath="/tmp/$scheme/$uuid.xcarchive"

echo "======================================== Log for archiving ========================================" >> "$log_path"

#showProcessingHint "Archiving." &
BG_PID="$!";trap "(kill -9 $BG_PID &);echo;reset2Development;exit -1" INT

echo "当前架构为 $TARTGET_ARCHS"
echo "当前DSYM 选项为 $DSYMOPTION"
echo "当前的SWIFT option为 $SWIFT_LEVEL_OPTION"
echo "the archiving path is $archivePath" 

xcodebuild archive  -quiet -workspace "$workspace" -scheme "$scheme" -sdk "iphoneos" -archivePath "$archivePath" ARCHS="${TARTGET_ARCHS}" SWIFT_OPTIMIZATION_LEVEL="${SWIFT_LEVEL_OPTION}" GCC_GENERATE_DEBUGGING_SYMBOLS="${DSYMOPTION}" -verbose | tee -a "$log_path" 2>&1

archiveResult="$?"

#kill "$BG_PID";wait "$BG_PID" 2>"/dev/null"
#echo

# recover SDK with development version BAK
rm -r -f "$zegoAVKit"
mv -f "$zegoAVKit_BAK" "$zegoAVKit"

# recover project config
if [[ "$op" == 3 ]]
then
    resetProjectConfig
fi

if  [[ "$archiveResult" != 0 ]]
then
    errmsg "Error occurred while archiving. Refer to the log for more infomation."
    exit -1
else
    okmsg "Archived."
fi

showInfo "Archive Path: $archivePath"

echo "" >> "$log_path"
echo "======================================== Log for exporting ========================================" >> "$log_path"

showProcessingHint "Exporting." &
BG_PID="$!";trap "(kill -9 $BG_PID &);echo;exit -1" INT

# To solve error - Error Domain=IDEDistributionErrorDomain Code=14 "No applicable devices found."
[[ -s "$HOME/.rvm/scripts/rvm" ]] && source "$HOME/.rvm/scripts/rvm"
rvm use system >> "$log_path" 2>&1
if [[ "$?" != 0 ]]
then
    errmsg "rvm command failed, export may not be excuted, refer to the log for more infomation."
fi

# http://blog.csdn.net/small_tgs/article/details/52175891
# curl -sSL https://get.rvm.io | bash
# source ~/.bashrc
# source ~/.bash_profile

exportPath="${outputDir}/$scheme $uuid"

xcodebuild -exportArchive -archivePath "$archivePath" -exportOptionsPlist "$exportOptions" -exportPath "$exportPath" >> "$log_path" 2>&1
exportResult="$?"

kill "$BG_PID";wait "$BG_PID" 2>"/dev/null"

#*****************************************这里还原BitCode的值*************************************#
if [[ $ENABLE_BITCODE = "YES" ]]; then
	##还原配置
    ENABLE_BITCODE="YES"
	functhParam "^.*4E3860E11B8C3D6600131962.*=" '                ENABLE_BITCODE = "NO";'
	functhParam "^.*6E1BCCEE1C328EFD006C4951.*=" '                ENABLE_BITCODE = "NO";'
fi
#************************************************************************************************#	

echo

if [[ "$exportResult" != 0 ]]
then
    errmsg "Error occurred while exporting. Refer to the log for more infomation."
    exit -1
else
    okmsg "Exported."
    cp -R "${archivePath}/dSYMs" "${exportPath}"
fi

#if [[ $op == 2 ]] # upload to AppStore
#then
#fi

if [[ "$op" == 3 ]] # upload to pgyer
then
    mv "$exportPath/TT_Enterprise.ipa" "$exportPath/$timeString.ipa"
    echo "" >> "$log_path"
    echo "======================================== Log for uploading ========================================" >> "$log_path"

    showProcessingHint "Uploading to pgy." &
    BG_PID="$!";trap "(kill -9 $BG_PID &);echo;exit -1" INT

    api="http://www.pgyer.com/apiv1/app/upload"
    uKey="413a03ab72e64ebb4fcc593647cef9ce"
    _api_key="f312e1a0df11d9b0b56befff254dc66f"

    retryTime=0
    curl -F "file=@$exportPath/$timeString.ipa" -F "uKey=$uKey" -F "_api_key=$_api_key" -F "installType=2" -F "password=9m2vy" "$api" >> "$log_path" 2>&1
    uploadResult="$?"
    while [[ "$uploadResult" != 0 ]]
    do
        if [[ "$retryTime" > 3 ]]
        then
            kill "$BG_PID";wait "$BG_PID" 2>"/dev/null"
            echo
            errmsg "Upload to pgy failed. Refer to the log for more infomation."
            break
        fi
        let retryTime+=1
        echo "-----------------------------------------------------------" >> "$log_path"
        echo "Upload retry times: $retryTime" >> "$log_path"
        curl -F "file=@$exportPath/$timeString.ipa" -F "uKey=$uKey" -F "_api_key=$_api_key" -F "installType=2" -F "password=9m2vy" "$api" >> "$log_path" 2>&1
        uploadResult="$?"
    done

    if [[ "$uploadResult" == 0 ]]
    then
        kill "$BG_PID";wait "$BG_PID" 2>"/dev/null"
        echo
        okmsg "Upload to pgy done."
    fi
    echo "" >> "$log_path"
fi

echo "======================================== End ========================================" >> "$log_path"
showInfo ">>>> Task ended."
echo "===================================================================================================="
echo

open "$archivePath" # Once open, it will be copied to xcode's directory automatically

[[ "$op" == 3 ]] && echo -e "ios新包已上传\nhttps://www.pgyer.com/tt-internal\n9m2vy" | pbcopy
open "$exportPath"

