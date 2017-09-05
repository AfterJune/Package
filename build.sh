#!/bin/sh

clear
# 常用到plistbuddy 定义个全局
plistBuddy="/usr/libexec/PlistBuddy"
xcodebuild="/usr/bin/xcodebuild"
security="/usr/bin/security"
codesign="/usr/bin/codesign"
shellPath=`pwd`
projectPath="$shellPath/.."
pbxprojFile=''
#工程文件类型 默认.xcworkspace
projTypeIsWorkSpace=true
buildTime=$(date +%Y-%m-%d-%H-%M)



echo "projectPath=$projectPath"
#============ 检查.xcodeproj文件 获取pbxprojFile以便后面进行修改配置 ===================#
if [[ "$xcodeProject" == '' ]]; then
xcodeProject=`find "$projectPath" -maxdepth 1  -type d -name "*.xcodeproj"`
fi

projectExtension=`basename "$xcodeProject" | cut -d'.' -f2`
if [[ "$projectExtension" != "xcodeproj" ]]; then
echo "Xcode project 应该带有.xcodeproj文件扩展，.${projectExtension}不是一个Xcode project扩展！"
exit 1
else
pbxprojFile="$xcodeProject/project.pbxproj"
if [[ ! -f "$pbxprojFile" ]]; then
echo "项目文件:\"$pbxprojFile\" 不存在"
exit 1;
fi
echo "发现pbxproj:$pbxprojFile"
fi
#==================================================================================#

#=====================检查.workspace文件判断是否是workspace工程=======================#
xcworkspace=`find "$xcodeProject/.." -maxdepth 1  -type d -name "*.xcworkspace"`
if [[ -d "$xcworkspace" ]]; then
projTypeIsWorkSpace=true
echo "发现xcworkspace:$xcworkspace"
else
projTypeIsWorkSpace=false;
fi
#=================================================================================#

#=====================svn 操作 ====================#
#=====================可以改成git操作===============#
cd ..
echo ${pwd}
svn update
svnVersion=`svnversion |sed 's/^.*://' |sed 's/[A-Z]*$//'`
echo $svnVersion

for y in $shellPath/module/*;
do
#==============读取config文件====================#
configFile=$y/config.plist
if [[ "$configFile" == '' ]]; then
echo "未找到config.plist文件！"
exit 1
fi
echo "找到config.plist文件"
configurations=`"$plistBuddy" -c "print :" "$configFile"`
echo "$configurations"

appVersion=`"$plistBuddy" -c "print :appVersion:" "$configFile"`
appBuildVersion=`"$plistBuddy" -c "print :appBuildVersion:" "$configFile"`
appName=`"$plistBuddy" -c "print :appName:" "$configFile"`
keychainPWD=`"$plistBuddy" -c "print :keychainPWD:" "$configFile"`
appID=`"$plistBuddy" -c "print :appID:" "$configFile"`
targetName=`"$plistBuddy" -c "print :targetName:" "$configFile"`
schemeName=`"$plistBuddy" -c "print :schemeName:" "$configFile"`
profileName=`"$plistBuddy" -c "print :profileName:" "$configFile"`
certificateName=`"$plistBuddy" -c "print :certificateName:" "$configFile"`
buildConfiguration=`"$plistBuddy" -c "print :buildConfiguration:" "$configFile"`
teamID=`"$plistBuddy" -c "print :teamID:" "$configFile"`
sdk=`"$plistBuddy" -c "print :SDK:" "$configFile"`
ftp=`"$plistBuddy" -c "print :ftp:" "$configFile"`

#================================================#

#==============查找Info.plist文件===================#
projectName=$(basename "$xcodeProject" .xcodeproj)
infoPlistPath=$projectPath/$projectName/Info.plist
echo "infoPlistPath = $infoPlistPath"
#修改Info.plist内容
if [[ -f "$infoPlistPath" ]]; then
if [[ "$appVersion" != '' ]]; then
$plistBuddy -c "Set :CFBundleShortVersionString $appVersion" "$infoPlistPath"
fi

if [[ "$appBuildVersion" != '' ]]; then
$plistBuddy -c "Set :CFBundleVersion $appBuildVersion" "$infoPlistPath"
echo "use appBuildVersion"
else
$plistBuddy -c "Set :CFBundleVersion $appVersion.$svnVersion" "$infoPlistPath"
echo "use svnVersion"
fi

if [[ "$appName" != '' ]]; then
$plistBuddy -c "Set :CFBundleName $appName" "$infoPlistPath"
fi

if [[ "$appID" != '' ]]; then
$plistBuddy -c "Set :CFBundleIdentifier $appID" "$infoPlistPath"
fi
echo "Info.plist 文件修改完成"
else
echo "$infoPlistPath Info.plist 没找到"
exit 1
fi
#================================================#

# ===========   keychain 授权 =====================#

#允许访问证书
$security unlock-keychain -p $loginPwd "$HOME/Library/Keychains/login.keychain" 2>/tmp/log.txt
if [[ $? -ne 0 ]]; then
echo "security unlock-keychain 失败!请检查配置密码是否正确"
exit 1
fi
$security unlock-keychain -p $loginPwd "$HOME/Library/Keychains/login.keychain-db" 2>/tmp/log.txt
if [[ $? -ne 0 ]]; then
echo "security unlock-keychain 失败!请检查配置密码是否正确"
exit 1
fi
# =================================================#

#==============检查证书和描述文件====================#
profileUUID=''
if [[ "$profileName" != "" ]]; then
profilePath=$y/$profileName.mobileprovision
if [[ ! -f "$profilePath" ]]; then
echo "描述文件 $profilePath 不存在！"
exit 1
fi
profileUUID=`$plistBuddy -c 'Print :UUID' /dev/stdin <<< $($security cms -D -i "$profilePath" 2>/tmp/log.txt)`
echo "描述文件UUID  $profileUUID"
fi
# =================================================#

# ===============检查构建ipa存放路径=================#
savePath=$projectPath/build/$buildTime
if [[ ! -d "$projectPath/build" ]]; then
mkdir $projectPath/build
fi
if [[ ! -d "$savePath" ]]; then
mkdir $savePath
fi
# =================================================#


# ===============开始打包=================#
exportPlistPath=$y/exportPlist.plist
if [[ "$exportPlistPath" == '' ]]; then
echo "未找到exportPlist.plist文件！"
exit 1
fi


if [[ $projTypeIsWorkSpace != true ]]; then

echo '*** 正在 清理工程 ***'
xcodebuild clean -project "${xcodeProject}" -scheme "${schemeName}" -configuration "${buildConfiguration}" -sdk $sdk
echo '*** 清理完成 ***'

echo '*** 正在 archive ***'
cmd="xcodebuild archive -archivePath ${savePath}/${schemeName}-${buildConfiguration}.xcarchive -project "${xcodeProject}" -scheme "${schemeName}" -configuration  "${buildConfiguration}" -sdk $sdk"
if [[ $profileUUID != '' ]];then
cmd="$cmd" PROVISIONING_PROFILE="${profileUUID}"
fi
if [[ $certificateName != '' ]];then
cmd="$cmd" PROVISIONING_PROFILE="${profileUUID}" CODE_SIGN_IDENTITY="${certificateName}"
fi
if [[ $teamID != '' ]];then
cmd="$cmd" DEVELOPMENT_TEAM="${teamID}"
fi
$cmd
echo '*** archive done***'

echo '*** 正在 exportArchive ***'
xcodebuild -exportArchive -archivePath ${savePath}/${schemeName}-${buildConfiguration}.xcarchive \
-configuration "${buildConfiguration}" \
-exportPath ${savePath} \
-exportOptionsPlist ${exportPlistPath} \
-quiet || exit
echo '*** exportArchive done***'

# xcode 8.3之前用xcrun
#   xcrun -sdk $sdk PackageApplication -v "${savePath}/${schemeName}.app" -o "${savePath}/${schemeName}-${buildConfiguration}.ipa"
else
echo '*** 正在 清理工程 ***'
xcodebuild clean -workspace "${xcworkspace}" -scheme "${schemeName}" -configuration "${buildConfiguration}" -sdk $sdk
echo '*** 清理完成 ***'

echo '*** 正在 archive ***'
cmd="xcodebuild archive -archivePath ${savePath}/${schemeName}-${buildConfiguration}.xcarchive -workspace "${xcworkspace}" -scheme "${schemeName}" -configuration  "${buildConfiguration}" -sdk $sdk"
if [[ $profileUUID != '' ]];then
cmd="$cmd" PROVISIONING_PROFILE="${profileUUID}"
fi
if [[ $certificateName != '' ]];then
cmd="$cmd" CODE_SIGN_IDENTITY="${certificateName}"
fi
if [[ $teamID != '' ]];then
cmd="$cmd" DEVELOPMENT_TEAM="${teamID}"
fi
$cmd
echo '*** archive done***'

echo '*** 正在 exportArchive ***'
xcodebuild -exportArchive -archivePath ${savePath}/${schemeName}-${buildConfiguration}.xcarchive \
-configuration "${buildConfiguration}" \
-exportPath ${savePath} \
-exportOptionsPlist ${exportPlistPath} \
-quiet || exit
echo '*** exportArchive done***'

# xcode 8.3之前用xcrun
#    xcrun -sdk $sdk PackageApplication -v "${savePath}/${schemeName}.app" -o "${savePath}/${schemeName}-${buildConfiguration}.ipa"
fi
#=================================================#
if [ -e $savePath/$schemeName.ipa ]; then
mv "${savePath}/${schemeName}.ipa" "${savePath}/${schemeName}${buildConfiguration}.ipa"
echo "*** .ipa文件已导出 ***"
else
echo "*** 创建.ipa文件失败 ***"
fi

#==============将.ipa上传ftp=======================#

if [[ $ftp != '' ]];then
echo "***开始上传ipa到ftp服务器***"
ftp -niv<<-!
open 123.58.173.196 3721
user s1609 g1BMITiVlo
binary
hash
cd ${ftp}
lcd ${savePath}
prompt
put ${schemeName}${buildConfiguration}.ipa
close
bye
!
echo "***完成上传ipa到ftp服务器***"
fi
#=================================================#

echo "***${schemeName}-${buildConfiguration}.ipa 打包完成 ***"
done
open $savePath
