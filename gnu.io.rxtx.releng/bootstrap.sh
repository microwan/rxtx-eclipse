#!/bin/bash
#
# bootstrap.sh for preparing RXTX build environment on osgiliath
#

# User specific environment and startup programs
umask 002

BASE_PATH=.:/bin:/usr/bin:/usr/bin/X11:/usr/local/bin:/usr/bin:/usr/X11R6/bin
LD_LIBRARY_PATH=.
BASH_ENV=$HOME/.bashrc
USERNAME=`whoami`
CVS_RSH=ssh
export CVS_RSH USERNAME BASH_ENV LD_LIBRARY_PATH

proc=$$

#notification list
recipients=

#sets skip.performance.tests Ant property
skipPerf=""

#sets skip.tests Ant property
skipTest=""

#sets sign Ant property
sign=""

tagMaps=""

#sets fetchTag="HEAD" for nightly builds if required
tag=""

# tag v20060907 is the one that includes the new build page
#buildProjectTags=v20060907
#buildProjectTags=v20060908
buildProjectTags=R3_3

#updateSite property setting
updateSite=""

#flag indicating whether or not mail should be sent to indicate build has started
mail=""

#flag used to build based on changes in map files
compareMaps=""

#buildId - build name
buildId=""

#buildLabel - name parsed in php scripts <buildType>-<buildId>-<datestamp>
buildLabel=""

# tag for build contribution project containing .map files
mapVersionTag=HEAD

# directory in which to export builder projects
builderDir=$HOME/rxtx/builds/builder

# buildtype determines whether map file tags are used as entered or are replaced with HEAD
buildType=N

# directory where to copy build
postingDirectory=$HOME/rxtx/builds/transfer/files/master/downloads/drops

#directory for rss feed - not used 
#rssDirectory=$HOME/rxtx/builds/transfer/files/master

# flag to indicate if test build
testBuild=""

# path to javadoc executable
javadoc=""

# value used in buildLabel and for text replacement in index.php template file
builddate=`date +%Y%m%d`
buildtime=`date +%H%M`
timestamp=$builddate$buildtime


# process command line arguments
usage="usage: $0 [-notify emailaddresses][-test][-buildDirectory directory][-buildId name][-buildLabel directory name][-tagMapFiles][-mapVersionTag tag][-builderTag tag][-compareMaps][-skipPerf] [-skipTest] [-skipRSS] [-updateSite site][-sign] M|N|I|S|R"

if [ $# -lt 1 ]
then
		 		  echo >&2 "$usage"
		 		  exit 1
fi

while [ $# -gt 0 ]
do
		 		  case "$1" in
		 		  		 		  -buildId) buildId="$2"; shift;;
		 		  		 		  -buildLabel) buildLabel="$2"; shift;;
		 		  		 		  -mapVersionTag) mapVersionTag="$2"; shift;;
		 		  		 		  -tagMapFiles) tagMaps="-DtagMaps=true";;
		 		  		 		  -skipPerf) skipPerf="-Dskip.performance.tests=true";;
		 		  		 		  -skipTest) skipTest="-Dskip.tests=true";;
		 		  		 		  -skipRSS) skipRSS="-Dskip.feed=true";;
		 		  		 		  -buildDirectory) builderDir="$2"; shift;;
		 		  		 		  -notify) recipients="$2"; shift;;
		 		  		 		  -test) postingDirectory="/builds/transfer/files/bogus/downloads/drops";testBuild="-Dtest=true";;
		 		  		 		  -builderTag) buildProjectTags="$2"; shift;;
		 		  		 		  -compareMaps) compareMaps="-DcompareMaps=true";;
		 		  		 		  -updateSite) updateSite="-DupdateSite=$2";shift;;
		 		  		 		  -sign) sign="-Dsign=true";;
		 		  		 		  -*)
		 		  		 		  		 		  echo >&2 $usage
		 		  		 		  		 		  exit 1;;
		 		  		 		  *) break;;		 		  # terminate while loop
		 		  esac
		 		  shift
done

# After the above the build type is left in $1.
buildType=$1

# Set default buildId and buildLabel if none explicitly set
if [ "$buildId" = "" ]
then
		 		  buildId=$buildType$builddate-$buildtime
fi

if [ "$buildLabel" = "" ]
then
		 		  buildLabel=$buildId
fi

#Set the tag to HEAD for Nightly builds
if [ "$buildType" = "N" ]
then
        tag="-DfetchTag=HEAD"
        versionQualifier="-DforceContextQualifier=$buildId"
fi

# tag for eclipseInternalBuildTools on ottcvs1
internalToolsTag=$buildProjectTags

# tag for exporting org.eclipse.releng.basebuilder
baseBuilderTag=$buildProjectTags

# tag for exporting the custom builder
#customBuilderTag=$buildProjectTags
customBuilderTag=HEAD

if [ -e $builderDir ]
then
		 		  builderDir=$builderDir$timestamp
fi

# directory where features and plugins will be compiled
buildDirectory=$builderDir/rxtx.build

mkdir -p $builderDir
cd $builderDir

#check out org.eclipse.releng.basebuilder
echo "Getting org.eclipse.releng.basebuilder ..."
cvs -Q -d :pserver:anonymous@dev.eclipse.org:/cvsroot/eclipse co -r $baseBuilderTag org.eclipse.releng.basebuilder

#check out gnu.io.rxtx.releng builder
echo "Getting gnu.io.rxtx.releng ..."
cvs -Q -d :pserver:mober@talia:/export1/data/cvsroot/mober co -r $customBuilderTag -d gnu.io.rxtx.releng rxtx/gnu.io.rxtx.releng
#if [ "$tagMaps" == "-DtagMaps=true" ]; then  
#  cvs -d :pserver:mober@talia:/export1/data/cvsroot/mober rtag -r $customBuilderTag v$buildId gnu.io.rxtx.releng;
#fi

#export JAVA_HOME=/opt/jdk1.5.0_11
export JAVA_HOME=/usr/lib64/jvm/java-1.5.0-sun
#export BOOTPATH=${JAVA_HOME}/jre/lib/vm.jar:${JAVA_HOME}/jre/lib/core.jar:${JAVA_HOME}/jre/lib/xml.jar:${JAVA_HOME}/jre/lib/security.jar
export BOOTPATH=${JAVA_HOME}/jre/lib/rt.jar
export JAVABIN=${JAVA_HOME}/jre/bin/java
export PATH=${JAVA_HOME}/bin:$PATH
javadoc="-Djavadoc15=${JAVA_HOME}/bin/javadoc"

mkdir -p $postingDirectory/$buildLabel
chmod -R 755 $builderDir

cd $builderDir/gnu.io.rxtx.releng

echo buildId=$buildId >> monitor.properties 
echo timestamp=$timestamp >> monitor.properties 
echo buildLabel=$buildLabel >> monitor.properties 
echo recipients=$recipients >> monitor.properties
echo log=$postingDirectory/$buildLabel/index.php >> monitor.properties

#the base command used to run AntRunner headless
antRunner="`which java` -Xmx500m -jar ../org.eclipse.releng.basebuilder/plugins/org.eclipse.equinox.launcher.jar -Dosgi.os=linux -Dosgi.ws=gtk -Dosgi.arch=x86 -application org.eclipse.ant.core.antRunner"
antRunnerJDK15="$JAVABIN -Xmx500m -jar ../org.eclipse.releng.basebuilder/plugins/org.eclipse.equinox.launcher.jar -Dosgi.os=linux -Dosgi.ws=gtk -Dosgi.arch=x86 -application org.eclipse.ant.core.antRunner"

#clean drop directories
#$antRunner -buildfile eclipse/helper.xml cleanSites

echo recipients=$recipients
echo postingDirectory=$postingDirectory
echo builderTag=$buildProjectTags
echo buildDirectory=$buildDirectory

#full command with args
#baseLocation=/home/data/users/moberhuber/ws/eclipse
baseLocation=$builderDir/org.eclipse.releng.basebuilder
buildCommand="$antRunner -q -buildfile buildAll.xml $mail $testBuild $compareMaps -DmapVersionTag=$mapVersionTag -DpostingDirectory=$postingDirectory -Dbootclasspath=$BOOTPATH -DbuildType=$buildType -D$buildType=true -DbuildId=$buildId -Dbuildid=$buildId -DbuildLabel=$buildLabel -Dtimestamp=$timestamp -DmapCvsRoot=:pserver:mober@talia:/export1/data/cvsroot/mober $skipPerf $skipTest $tagMaps -DbaseLocation=$baseLocation -DlogExtension=.xml $javadoc $updateSite $sign -DgenerateFeatureVersionSuffix=true -Djava15-home=$JAVA_HOME"

# -listener org.eclipse.releng.build.listeners.EclipseBuildListener"

#capture command used to run the build
echo $buildCommand>command.txt
echo "Dumped command to command.txt: to perform only the build, do"
echo "cd `pwd`"
echo "sh command.txt"

#run the build
$buildCommand
retCode=$?

if [ $retCode != 0 ]
then
        echo "Build failed (error code $retCode)."
        exit -1
fi

#if [ "$skip.feed" != "true" ]
#then
#$buildCommandRSS="$antRunnerJDK15 -buildfile $builderDir/org.eclipse.releng.basebuilder/plugins/org.eclipse.build.tools/scripts_rss/feedManipulation.xml"
#echo $buildCommandRSS>commandRSS.txt
##run the RSS command
#$buildCommandRSS
#fi



#clean up
rm -rf $builderDir


