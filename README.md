

### 本脚本主要用于xcode 8.3 之后的iOS项目自动编译打包ipa并上传ftp。其中ftp路径和端口和用户名密码固定写死，有需要的可以自己修改脚本添加配置调整。

##### 使用方式：

	> 一、将Package文件夹放入和.xcodeproj和.xcworkspace文件相同目录
	
	> 二、配置Package/module
	   本文件夹主要包含各种环境下的ipa配置
	     1.config.plist主要是对ipa的一些基本配置
		appVersion  版本号  1.0.0 不设置则使用xcode中的配置
		appBuildVersion  编译版本号 1.1.1 不设置则使用xcode中的配置
		appName  APP安装名称  微信  不设置则使用xcode中的配置
		keychainPWD  电脑密码  用来开启钥匙串访问权限
		appID     bundleID  用来签名 不设置则使用xcode中的配置
         *targetName  要编译的Target
         *schemeName  要编译的scheme
		profileName 描述文件名称 mtsdev
		certificateName 证书名称 iPhone Developer: Jesn Lu (HMKH2T59D9)
         *buildConfiguration  编译环境 Debug | Release
         *teamID   开发团队id
         *sdk      编译用的sdk包 iphoneos
         ftp      上传到ftp的路径  /wow/development 不填则不上传ftp

	     2.exportPlist.plist  xcode 8.3之后xcodebuild exprot必须要有的配置文件可以没有内容
		teamID   开发团队id
		method   app-store  |  enterprise   |   ad-hoc   |   development
		uploadSymbols YES | NO
		uploadBitcode YES | NO

	     3.如果profileName不为空则必须在当前目录下放置”$profileName”. mobileprovision 文件

	> 三、终端（Terminal）cd到../Package/build.sh  然后./build.sh  或者sudo sh build.sh
