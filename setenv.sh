# $Log: C:\Source_Code\UMDCommon\trunk\xxpck_db_top\xxpck\11.5.0\bin  $
# $Id: setenv.sh 1302 2011-05-19 14:07:43Z mshapira $
# Copyright Unitask Inc., 1999-2013. All rights reserved
#
#    Rev 115.20   Mar 03 2013 15:05:00   amp
# included compress/uncompress commands for compatibility
#
#    Rev 115.19   Dec 12 2012 15:05:00   amp
# removed windows related code, code clean up
# 
#    Rev 115.18   Jan 05 2005 17:32:50   guyl
# use java instead of jre
# 
#    Rev 115.17   Jan 05 2005 16:54:12   guyl
# SSL Support Added
# 
#    Rev 115.16   Aug 12 2004 11:02:52   guyl
# CLASSPATH - remove old and unused jars
# 
#    Rev 115.15   Aug 09 2004 21:00:14   guyl
# CLASSPATH updated
# 
#    Rev 115.14   Mar 08 2004 00:22:22   alexr
# nawk fix
# 
#    Rev 115.13   Mar 08 2004 00:21:06   alexr
# Fix nawk search
# 
#    Rev 115.12   Feb 22 2004 23:50:46   guyl
# change upload dir
# 
#    Rev 115.10   Feb 15 2004 18:12:22   guyl
# Version numbering
#

#######################################################################
#
# Set Environment Variables for UMD Scripts ...
#

# 
# Set awk Command ...
#
set +e
echo "test nawk" | nawk '{ print $0 }' 2> /dev/null
if [ $? -eq 0 ]
then
   AWK=nawk
else
   AWK=awk 
fi
export AWK
# set -e

#
# TNS Ping Command ...
#
TNSPING=tnsping
export TNSPING

# 
# Java Classpath ...
#
ORIG_CLASSPATH=$CLASSPATH
export ORIG_CLASSPATH

CLASSPATH=$XXPCK_TOP/java/jar/xxpckDbUtils.jar:$XXPCK_TOP/java/jar/orai18n-mapping.jar:$XXPCK_TOP/java/jar/orai18n-collation.jar:$XXPCK_TOP/java/jar/xxpckUtils.jar:$XXPCK_TOP/java/jar/MultiPart.jar:$XXPCK_TOP/java/jar/jcert.jar:$XXPCK_TOP/java/jar/jnet.jar:$XXPCK_TOP/java/jar/jsse.jar:$OA_JAVA/jdbc111.zip:$OA_JAVA:$XXPCK_TOP/java/jar/xxpckCheckSum.jar:$CLASSPATH:$XXPCK_TOP/java/jar/xxpckDownloadReport.zip
export CLASSPATH

# 
# Java Command 
#
JAVA_JRE=java
export JAVA_JRE

#
# EBS Forms Generation Command ...
#
FGEN=f60gen
export FGEN

#
# EBS Forms Path ...
#
FORMS60_PATH=$AU_TOP/forms/US:$AU_TOP/resource:$INSTALL_DIR
export FORMS60_PATH

#
# System Path ...
#
PATH=$XXPCK_TOP/bin:$PATH
export PATH

#
# TWO_TASK ...
# 
#echo TWO_TASK=$TWO_TASK
#NEW_TWO_TASK=`echo $TWO_TASK | awk -F"_" '{ print $1 }'`
#export $NEW_TWO_TASK
#if [ "$TWO_TASK" != "$NEW_TWO_TASK" ]
#then
#   TWO_TASK=`echo ${NEW_TWO_TASK}"1"`
#fi;
#export TWO_TASK

NEW_TWO_TASK=`$TNSPING $TWO_TASK | grep -i "ADDRESS" | $AWK -v tns_token=instance_name -f $XXPCK_TOP/bin/get_tns_param.awk`
export $NEW_TWO_TASK

SERVICE_NAME=`$TNSPING $TWO_TASK | grep -i "ADDRESS" | $AWK -v tns_token=service_name -f $XXPCK_TOP/bin/get_tns_param.awk`
export $SERVICE_NAME

if [ "$TWO_TASK" != "$NEW_TWO_TASK" ]
then
   TWO_TASK=`echo ${TWO_TASK}`
fi;
export TWO_TASK

#
# Jar Command ...
#
JAR="jar"
export JAR

#
# UMD Upload Directory ...
#
UPLOAD_DIR='$XXPCK_TOP/uploads'
export UPLOAD_DIR

#
# DB Port ...
#
XXPCK_DB_PORT=`$TNSPING $TWO_TASK | grep -i "ADDRESS" | $AWK -v tns_token=port -f $XXPCK_TOP/bin/get_tns_param.awk`
export XXPCK_DB_PORT
#echo PORT=$XXPCK_DB_PORT

# 
# DB Host ...
#
XXPCK_DB_HOST=`$TNSPING $TWO_TASK | grep -i "ADDRESS" | $AWK -v tns_token=host -f $XXPCK_TOP/bin/get_tns_param.awk`
export XXPCK_DB_HOST
#echo HOST=$XXPCK_DB_HOST

#
# SSL Parameters (need to be changed for sites using SSL, i.e. certificate keystore path/file and password)
#
SSL_PARAMS="-Djava.protocol.handler.pkgs=com.sun.net.ssl.internal.www.protocol -Djavax.net.ssl.trustStore=/unitask/ssl/cacerts -Djavax.net.ssl.trustStorePassword=unitask"
export SSL_PARAMS

#
# SQL*Plus ...
#
SQLPLUS="sqlplus -s"
export SQLPLUS

#
# Get DBC Information ...
#
export  APPS_LOGON="apps/apps"
echo APPS_PWD
echo $APPS_LOGON
DBC=`$SQLPLUS $APPS_LOGON @$XXPCK_TOP/sql/get_dbc_file.sql | grep -v "^$" | grep -v password`
DBC=`echo $DBC`

DBC_TMP=$$
cat $FND_SECURE/$DBC.dbc | tr -d "\\\\" > $FND_SECURE/$DBC.dbc.$DBC_TMP

#
# Get JDBC Information from DBC ...
#
JDBC=`cat $FND_SECURE/$DBC.dbc.$DBC_TMP | grep APPS_JDBC_URL | $AWK '{print substr($0,index($0,"=")+1)}'`
rm $FND_SECURE/$DBC.dbc.$DBC_TMP
JDBC=`echo $JDBC`

#
# If JDBC not in DBC file, then build connection string from DB parameters ...
#
if [ "${JDBC}" = "" ]
then
  JDBC="jdbc:oracle:thin:@(DESCRIPTION=(LOAD_BALANCE=YES)(FAILOVER=YES)(ADDRESS_LIST=(ADDRESS=(PROTOCOL=tcp)(HOST=${DB_HOST})(PORT=${DB_PORT})))(CONNECT_DATA=(SID=${TWO_TASK})))"
fi
export JDBC

#######################################################################
#
# Add Site Cusomizations below ...
#

#
# Serena dmcli Client Command Integration ...
#
#DMCLI_PATH="/opt/serena/dimensions/12.2/cm"
#export DMCLI_PATH

#
# MultiNode(s) - Non Shared Servers Configuration ...
#
# Concurrent Server Nodes ...
#
#CONC_NODE1=""
#export CONC_NODE1
#CONC_NODE2=""
#export CONC_NODE2
#
# Application Server Nodes ...
#
#ALTERNATIVE_APP_NODE1=""
#export ALTERNATIVE_APP_NODE1
#ALTERNATIVE_APP_NODE2=""
#export ALTERNATIVE_APP_NODE2
#ALTERNATIVE_APP_NODE3=""
#export ALTERNATIVE_APP_NODE3
#ALTERNATIVE_APP_NODE4=""
#export ALTERNATIVE_APP_NODE4

#
# SVN Optional Configurations ...
#
#XXPCK_SVN_TRUNK="trunk"
#export XXPCK_SVN_TRUNK
#XXPCK_SVN_BRANCH="branches"
#export XXPCK_SVN_BRANCH
#XXPCK_SVN_TAGS="tags"
#export XXPCK_SVN_TAGS
#XXPCK_USE_KEYWORDS="Y"
#export XXPCK_USE_KEYWORDS

#
# Alias compress and uncompress commands (Set also for Solaris and AIX environments for Package Compatibility) ...
#
alias compress='gzip -S .Z'
alias uncompress='gzip -d'


