#!/usr/bin/python
# -*- coding: utf-8 -*-

import os, shelve, sys, fileinput, re
from plistlib import *
from qiniu import *

Workspace = os.getcwd()

QiniuAccessKey = "i8m3lz89N5AGghEJC5n_cFIZ9QamW4U28Oxgdj7r"
QiniuSecretKey = "BKI2xDmiyUOACaEsiTCqYS3JvxOekzxr623x2jxi"
QiniuBucketName = "ties"

OriginalBundleID = "com.yiyou.tt"
BundleIDStub = ""
EnterpriseBundleID = "com.yiyou.enterprise.tt"

EnterpriseChannel = "Enterprise"

InstallPlistTemplate = """
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
	<key>items</key>
	<array>
		<dict>
			<key>assets</key>
			<array>
				<dict>
					<key>kind</key>
					<string>software-package</string>
					<key>url</key>
					<string>https://dn-ttios.qbox.me/{IPA_CdnKey}</string>
				</dict>
				<dict>
					<key>kind</key>
					<string>full-size-image</string>
					<key>needs-shine</key>
					<false/>
					<key>url</key>
					<string>https://dn-ttios.qbox.me/Icon@2x.png</string>
				</dict>
				<dict>
					<key>kind</key>
					<string>display-image</string>
					<key>needs-shine</key>
					<false/>
					<key>url</key>
					<string>https://dn-ttios.qbox.me/Icon.png</string>
				</dict>
			</array>
			<key>metadata</key>
			<dict>
				<key>bundle-identifier</key>
				<string>com.yiyou.enterprise.tt</string>
				<key>bundle-version</key>
				<string>{Bundle_Version}</string>
				<key>kind</key>
				<string>software</string>
				<key>title</key>
				<string>TT</string>
			</dict>
		</dict>
	</array>
</dict>
</plist>
"""

def print_progress(filename, size, sended, prefix=""):
	if prefix != None:
		prefix = prefix + " "
		bar_length = 100
		percent = float(sended) / float(size)
		hashes = '#' * int(percent * bar_length)
		spaces = ' ' * (bar_length - len(hashes))
		sys.stdout.write("\r%s%s: [%s] %.2f%%"%(prefix, filename, hashes + spaces, percent * 100.0))
		sys.stdout.flush()

def getBundleVersion():
	key = 'CurrentBundleVersion'
	versionConfPath = os.path.join("/Users/ci_ios/Workspace", "VersionConf")
	verconf = shelve.open(versionConfPath)
	if key not in verconf:
		verconf[key] = 1
	bundleVersion = verconf[key]
	verconf.close()

	return bundleVersion

def increaseBundleVersion():
	key = 'CurrentBundleVersion'
	versionConfPath = os.path.join("/Users/ci_ios/Workspace", "VersionConf")
	verconf = shelve.open(versionConfPath)
	if key in verconf:
		verconf[key] += 1
	else:
		verconf[key] = 1
	verconf.close()

def modifyInfoPlist():

	projectPath = os.path.join(Workspace, "TT/TT.xcodeproj/project.pbxproj")
	for line in fileinput.input(projectPath, inplace=True):
		if re.search(OriginalBundleID, line):
			line = line.replace(OriginalBundleID, EnterpriseBundleID)
		print line

	build = getBundleVersion()
	channel = EnterpriseChannel

	plistPath = os.path.join(Workspace, "TT/TT/Info.plist")
	plist = readPlist(plistPath)
	plist['TTChannelId'] = channel
	plist['CFBundleVersion'] = str(build)
	plist['CFBundleIdentifier'] = EnterpriseBundleID
	writePlist(plist, plistPath)

	for line in fileinput.input(plistPath, inplace=True):
		if re.search(OriginalBundleID, line):
			line = line.replace(OriginalBundleID, EnterpriseBundleID)
		print line

	version = plist['CFBundleShortVersionString']
	return (version, build, channel)

def getDestPath(version, build):
	buildPath = os.path.join(Workspace, "build")
	destPath = os.path.join(buildPath, "%s/%s" % (version, build))

	return destPath

def getIPACdnKey(version, build, channel):
	return "%s/%s/%s/TT.ipa" % (version, build, channel)

def getPlistCdnKey(version, build, channel):
	return "%s/%s/%s/TT.plist" % (version, build, channel)

def ipaBuild(version, build, channel):
	destPath = getDestPath(version, build)
	destIPA = "TT_%s.ipa" % channel
	cmd = """ipa build --xcargs "GCC_PREPROCESSOR_DEFINITIONS='${inherited} DISTRIBUTION=1 ENABLE_LAB'" -d "%s" -s TT -c Enterprise  --archive --ipa %s --verbose""" % (destPath, destIPA)
	print "Command: %s" % cmd
	ret = os.system(cmd)

	destFile = os.path.join(destPath, destIPA)
	return (ret, destFile)

def generateInstallPlist(version, build, channel, ipaCdnKey):
	destPath = getDestPath(version, build)
	destPlist = os.path.join(destPath, "TT_%s.plist" % channel)
	bundleVersion = "%s.%s" % (version, build)
	plistContent = InstallPlistTemplate.format(IPA_CdnKey=ipaCdnKey, Bundle_Version=bundleVersion)
	with open(destPlist, "w+") as f:
		f.write(plistContent)
	return destPlist

def upload2Qiniu(path, key):
	auth = Auth(QiniuAccessKey, QiniuSecretKey)
	token = auth.upload_token(QiniuBucketName, key, 7200)
	fileSize = os.path.getsize(path)
	print_progress(key, fileSize, 0, prefix = "Uploading")
	ret, info = put_file(token, key, path, progress_handler=lambda completed, total: print_progress(key, total, completed, prefix="Uploading"))
	if ret == None:
		raise Exception(info)

if __name__ == '__main__':
	try:
		version, build, channel = modifyInfoPlist()
		print version, build, channel

		print "Begin building: " 
		ret, ipaPath = ipaBuild(version, build, channel)

		ipaCdnKey = getIPACdnKey(version, build, channel)
		plistCdnKey = getPlistCdnKey(version, build, channel)

		plistPath = generateInstallPlist(version, build, channel, ipaCdnKey)

		print "Uploading IPA: " 
		upload2Qiniu(ipaPath, ipaCdnKey)

		print ""

		print "Uploading Plist: " 
		upload2Qiniu(plistPath, plistCdnKey)

		increaseBundleVersion()
	except Exception, e:
		print e

