#!/bin/ksh

# $Id: direct_print_WINDOWS.sh 1724 2011-10-06 18:34:35Z testuser $
# Copyright Unitask Inc 1999-2006

FILE=$1
FILE_TYPE=$2
PRINTER=$3
LOGON=$DB_USER/$DB_PWD
LOG=$5

. $XXLPR_TOP/bin/setenv.sh

# 
# Specific paper size - for converion from PDF only
#
if [ "$PAPER_SIZE_W" != "" ] && [ "$PAPER_SIZE_H" != "" ]
then
   PDF_TO_PS_CMD=" -paperw $PAPER_SIZE_W -paperh $PAPER_SIZE_H"
fi

#
# Specific duplex command - for convertion from PDF only
#
if [ "$DUPLEX" = "Y" ] || [ "$DUPLEX" = "Yes" ]
then
   DUPLEX_CMD="-duplex"
fi

#
# Samba credentials
#
SMB_USAGE=`echo $DB_PWD | $SQLPLUS $DB_USER @$XXLPR_TOP/sql/xxlpr_smb_usage.sql | grep -v "^$" | grep -v password`
SMB_USAGE=`echo $SMB_USAGE`
echo "Use smbclient="$SMB_USAGE >> $LOG
SMB_DETAILS=`echo $DB_PWD | $SQLPLUS $DB_USER @$XXLPR_TOP/sql/xxlpr_smb_details.sql "${PRINTER}" | grep -v "^$" | grep -v password`
SMB_HOST=`echo $SMB_DETAILS | $AWK -F"%" '{ print $1}'`
SMB_USER=`echo $SMB_DETAILS | $AWK -F"%" '{ print $2}'`
SMB_USER=`echo $SMB_USER | sed 's/\^/\\\\/g'`
SMB_PASS=`echo $SMB_DETAILS | $AWK -F"%" '{ print $3}'`

# 
# Display Parameters ...
#
echo "Samba host="$SMB_HOST >> $LOG
echo "Samba user="$SMB_USER >> $LOG
echo "PATH=$PATH" >> $LOG
echo "CLASSPATH for Samba=$CLASSPATH" >> $LOG

#
# DB_HOST and DB_PORT ...
#
DB_HOST=`tnsping $TWO_TASK | grep -i "ADDRESS" | $AWK -v tns_token=host -f $XXLPR_TOP/bin/get_tns_param.awk`
echo "DB_HOST=$DB_HOST"
DB_PORT=`tnsping $TWO_TASK | grep -i "ADDRESS" | $AWK -v tns_token=port -f $XXLPR_TOP/bin/get_tns_param.awk` 
echo "DB_PORT=$DB_PORT" 

# 
# Get DBC File ...
#
DBC=`echo $DB_PWD | $SQLPLUS $DB_USER @$XXLPR_TOP/sql/get_dbc_file.sql | grep -v "^$" | grep -v password`
DBC=`echo $DBC`
DBC_TMP=$$
cat $FND_SECURE/$DBC.dbc | tr -d "\\\\" > $FND_SECURE/$DBC.dbc.$DBC_TMP

# 
# JDBC Connection String ...
#
JDBC=`cat $FND_SECURE/$DBC.dbc.$DBC_TMP | grep APPS_JDBC_URL | $AWK '{print substr($0,index($0,"=")+1)}'`
rm $FND_SECURE/$DBC.dbc.$DBC_TMP
JDBC=`echo $JDBC`
if [ "${JDBC}" = "" ]
then
   JDBC="jdbc:oracle:thin:@(DESCRIPTION=(LOAD_BALANCE=YES)(FAILOVER=YES)(ADDRESS_LIST=(ADDRESS=(PROTOCOL=tcp)(HOST=${DB_HOST})(PORT=${DB_PORT})))(CONNECT_DATA=(SID=${TWO_TASK})))"
fi
echo "JDBC_CONNECTION_STRING=$JDBC"

# 
# Java Classpath ...
#
CLASSPATH=$XXLPR_TOP/java/jar/jdbc.jar:$XXLPR_TOP/java/jar/bcprov-jdk15on-1.63.jar:$XXLPR_TOP/java/jar/jcifs-ng-2.1.8.jar:$XXLPR_TOP/java/jar/xmlparserv2-904.zip:$XXLPR_TOP/java/jar/XXLPR_WIN_UTILS.jar:$CLASSPATH
export CLASSPATH

#
# Convert to upper case
#
FILE_TYPE=`echo $FILE_TYPE | tr '[a-z]' '[A-Z]'`

#
# Ghostscript ...
#
GS_LIB=$XXLPR_TOP/gs/bin:$XXLPR_TOP/gs/fonts
export GS_LIB

#
# Printer ...
#
PRINTER=`echo $FORMATTED_PRINTER | sed 's/\^/ /g'`
PRINTER_DETAILS=`sqlplus -s $LOGON @ $XXLPR_TOP/sql/xxlpr_get_printer_details.sql "${FORMATTED_PRINTER}"  "${REQUEST_ID}"| grep -v "^$"`
PRINTER_DETAILS=`echo $PRINTER_DETAILS`
RESULT=`echo $PRINTER_DETAILS | $AWK -F"%" '{ print $1 }'`
if  [ "${RESULT}" = "DIRECT" ]
then
   PRINTER_LANG=`echo $PRINTER_DETAILS | $AWK -F"%" '{ print $2 }'`
   HOST=`echo $PRINTER_DETAILS | $AWK -F"%" '{ print $3 }'`
   PORT=`echo $PRINTER_DETAILS | $AWK -F"%" '{ print $4 }'`
else
   echo "Didn't get extected Protocol " >> $LOG
   exit 1
fi

# 
# Handle RAW printing
# 
if [ "$FILE_TYPE" = "RAW" ] || [ "$PRINTER_LANG" = "RAW" ]
then
   #
   # Duplex ...
   # 
   if [ "$DUPLEX" = "Y" ] || [ "$DUPLEX" = "Yes" ]
   then
      echo ""  >> $LOG
      echo "   Cannot enable duplex command on RAW output. The output will be printed according to your printer settings" >> $LOG
      echo ""  >> $LOG
   fi
   # 
   # Send to Device via Java or native SMB client ...
   #
   echo "(RAW File) Printing $FILE as is..." >> $LOG
   if [ "${SMB_USAGE}" = "N" ]
   then
      nohup $JAVA_JRE -mx1024m unitask.oracle.apps.xxlpr.winutils.PrintDocumentHandler $FILE $DB_USER $DB_PWD "$JDBC" $FORMATTED_PRINTER $CONF_FILE &
      #$JAVA_JRE -mx1024m unitask.oracle.apps.xxlpr.winutils.PrintDocumentHandler $FILE $DB_USER $DB_PWD "$JDBC" $FORMATTED_PRINTER $CONF_FILE &
   else
      nohup cat $FILE | smbclient "//${SMB_HOST}/${PRINTER}" -c "print -" -U ${SMB_USER}%${SMB_PASS} &
   fi # native or java client
fi;

#
# Unique Number ...
#
GUID=$$

# 
# Handle PS
# 
if [ "$FILE_TYPE" = "PS" ] && [ "$PRINTER_LANG" = "PS" ]
then
   echo "Sending $FILE to the $PRINTER without Windows Print conversion..." >> $LOG
   # 
   # Margins ...
   #
   if [ "${MARGIN}" != "" ]
   then
      echo "Margins ${MARGIN} ${FILE} ... " >> $LOG
      $XXLPR_TOP/gs/bin/gs -dSAFER -q -dNOPAUSE -dCompatibilityLevel=1.2 -dBATCH -sDEVICE=pswrite -sOutputFile=`pwd`/$OUT_FILE.ps.tmp  -dSAFER $XXLPR_TOP/gs/bin/${MARGIN} $FILE
      mv $OUT_FILE.ps.tmp ${FILE}_${GUID}
      SZ=$(du -h ${FILE}_${GUID} | $AWK '{ print $1 }')
      echo "PS File Size after Margins Conversion: ${SZ}" >> $LOG
   else
      echo "No Margins ${FILE} ..." >> $LOG
      mv $FILE ${FILE}_${GUID}
   fi
   #
   # Send to Device via Java or native SMB client ...
   #
   if [ "${SMB_USAGE}" = "N" ]
   then
      nohup $JAVA_JRE -mx1024m unitask.oracle.apps.xxlpr.winutils.PrintDocumentHandler ${FILE}_${GUID} $DB_USER $DB_PWD "$JDBC" $FORMATTED_PRINTER $CONF_FILE &
      #$JAVA_JRE -mx1024m unitask.oracle.apps.xxlpr.winutils.PrintDocumentHandler ${FILE}_${GUID} $DB_USER $DB_PWD "$JDBC" $FORMATTED_PRINTER $CONF_FILE &
   else
      nohup cat ${FILE}_${GUID} | smbclient "//${SMB_HOST}/${PRINTER}" -c "print -" -U ${SMB_USER}%${SMB_PASS} &
   fi; # native or java client
   #
   # Results ...
   # 
   if [ "$?" = "0" ]
   then
      echo "File Printed" >> $LOG
   else
      echo "Error: $? " >> $LOG
      exit 1
   fi
fi;

#
# PS to PCL ... 
# 
if [ "$FILE_TYPE" = "PS" ] && [ "$PRINTER_LANG" = "PCL" ]
then
   echo "Converting $FILE to the PCL format" >> $LOG
   # 
   # Margins ...
   #
   if [ "${MARGIN}" != "" ]
   then
      $XXLPR_TOP/gs/bin/gs -dSAFER -q -dNOPAUSE -dCompatibilityLevel=1.2 -dBATCH -sDEVICE=pswrite -sOutputFile=`pwd`/$OUT_FILE.ps.tmp  -dSAFER $XXLPR_TOP/gs/bin/${MARGIN} $FILE
      mv  $OUT_FILE.ps.tmp ${FILE}_${GUID}
      $XXLPR_TOP/gs/bin/gs  -q -dNOPAUSE -dBATCH -dNORANGEPAGESIZE -sDEVICE=pxlcolor  -sOutputFile=${OUT_FILE}_1.pcl ${FILE}_${GUID}
   else
      $XXLPR_TOP/gs/bin/gs  -q -dNOPAUSE -dBATCH -sDEVICE=pxlcolor  -sOutputFile=${OUT_FILE}_1.pcl $FILE
   fi
   mv ${OUT_FILE}_1.pcl ${FILE}_${GUID}
   SZ=$(du -h ${FILE}_${GUID} | $AWK '{ print $1 }')
   echo "PCL File Size after Conversion: ${SZ}" >> $LOG
   #
   # Send File to Device ... 
   # 
   echo "Sending $FILE to the $PRINTER after Windows Print conversion..." >> $LOG
   if [ "${SMB_USAGE}" = "N" ]
   then
      nohup $JAVA_JRE -mx1024m unitask.oracle.apps.xxlpr.winutils.PrintDocumentHandler ${FILE}_${GUID} $DB_USER $DB_PWD "$JDBC" $FORMATTED_PRINTER $CONF_FILE &
      #$JAVA_JRE -mx1024m unitask.oracle.apps.xxlpr.winutils.PrintDocumentHandler ${FILE}_${GUID} $DB_USER $DB_PWD "$JDBC" $FORMATTED_PRINTER $CONF_FILE &
   else
      nohup cat ${FILE}_${GUID} | smbclient "//${SMB_HOST}/${PRINTER}" -c "print -" -U ${SMB_USER}%${SMB_PASS} &
   fi # native or java client
   #
   # Results ...
   #
   if [ "$?" = "0" ]
   then
      echo "File Printed" >> $LOG
   else
      echo "Error: $? " >> $LOG
      exit 1
   fi
   # 
   # Clean Up ...
   #
   if [ -e "{FILE}_${GUID}" ]
   then
      echo ""
      #rm ${FILE}_${GUID} 
   fi
fi;

#
# PDF to PS ...
# 
if [ "$FILE_TYPE" = "PDF" ] && [ "$PRINTER_LANG" = "PS" ]
then
   echo "Converting $FILE to the PS format using pdftops utility.." >> $LOG
   $XXLPR_TOP/pdftops/xpdf/pdftops $PDF_TO_PS_CMD $DUPLEX_CMD $FILE `pwd`/out.ps.$GUID
   # 
   # Add Fonts ...
   #
   if [ "$ADDFONTS" != "" ]
   then
      cat $ADDFONTS/PSFONTS/* `pwd`/out.ps.$GUID > $FILE.tmp
      mv $FILE.tmp  `pwd`/out.ps.$GUID
   fi
   #
   # Margins ...
   #
   if [ "${MARGIN}" != "" ]
   then
      $XXLPR_TOP/gs/bin/gs -dSAFER -q -dNOPAUSE -dCompatibilityLevel=1.2 -dBATCH -sDEVICE=pswrite -sOutputFile=`pwd`/$OUT_FILE.ps.tmp  -dSAFER $XXLPR_TOP/gs/bin/${MARGIN}  `pwd`/out.ps.$GUID
      mv `pwd`/$OUT_FILE.ps.tmp `pwd`/out.ps.$GUID
      SZ=$(du -h `pwd`/out.ps.$GUID | $AWK '{ print $1 }')
      echo "PS File Size after Margins Conversion: ${SZ}" >> $LOG
   fi
   #
   # Send to Device via Java or native SMB client ...
   #
   echo "Sending `pwd`/out.ps.$GUID to the $PRINTER after Windows Print conversion..." >> $LOG
   if [ "${SMB_USAGE}" = "N" ]
   then
      nohup $JAVA_JRE -mx1024m unitask.oracle.apps.xxlpr.winutils.PrintDocumentHandler `pwd`/out.ps.$GUID $DB_USER $DB_PWD "$JDBC" $FORMATTED_PRINTER $CONF_FILE &
      #$JAVA_JRE -mx1024m unitask.oracle.apps.xxlpr.winutils.PrintDocumentHandler `pwd`/out.ps.$GUID $DB_USER $DB_PWD "$JDBC" $FORMATTED_PRINTER $CONF_FILE &
   else
      nohup cat `pwd`/out.ps.$GUID | smbclient "//${SMB_HOST}/${PRINTER}" -c "print -" -U ${SMB_USER}%${SMB_PASS} &
   fi # native or java client
   # 
   # Results ...
   #
   if [ "$?" = "0" ]
   then
      echo "File Printed" >> $LOG
   else
      echo "Error: $? " >> $LOG
      exit 1
   fi
   #
   # Clean Up ...
   #
   if [ -e "`pwd`/out.ps.$GUID" ]
   then
      echo ""
      #rm `pwd`/out.ps.$GUID
   fi
fi;

#
# PDF to (PS to) PCL ...
# 
if [ "$FILE_TYPE" = "PDF" ] && [ "$PRINTER_LANG" = "PCL" ]
then
   echo "Converting $FILE to the PS format using pdftops utility.." >> $LOG
   $XXLPR_TOP/pdftops/xpdf/pdftops  $PDF_TO_PS_CMD $DUPLEX_CMD $FILE `pwd`/out.ps.$GUID
   SZ=$(du -h `pwd`/out.ps.${GUID} | $AWK '{ print $1 }')
   echo "PS File Size after Conversion: ${SZ}" >> $LOG
   # 
   # Add Fonts ...
   #
   if [ "$ADDFONTS" != "" ]
   then
      cat $ADDFONTS/PSFONTS/* `pwd`/out.ps.$GUID > $FILE.tmp
      mv $FILE.tmp  `pwd`/out.ps.$GUID
   fi
   # 
   # Margins ...
   #
   echo "Converting `pwd`/out.ps.$GUID to the PCL format" >> $LOG
   if [ "${MARGIN}" != "" ]
   then
      $XXLPR_TOP/gs/bin/gs -dSAFER -q -dNOPAUSE -dCompatibilityLevel=1.2 -dBATCH -sDEVICE=pswrite -sOutputFile=`pwd`/$OUT_FILE.ps.tmp  -dSAFER $XXLPR_TOP/gs/bin/${MARGIN} `pwd`/out.ps.$GUID
      mv  $OUT_FILE.ps.tmp $OUT_FILE.ps
      $XXLPR_TOP/gs/bin/gs  -q -dNOPAUSE -dBATCH -dNORANGEPAGESIZE -sDEVICE=pxlcolor  -sOutputFile=${OUT_FILE}_1.pcl $OUT_FILE.ps
   else
      $XXLPR_TOP/gs/bin/gs  -q -dNOPAUSE -dBATCH -sDEVICE=pxlcolor  -sOutputFile=${OUT_FILE}_1.pcl `pwd`/out.ps.$GUID
   fi
   mv ${OUT_FILE}_1.pcl `pwd`/out.pcl.${GUID}
   SZ=$(du -h `pwd`/out.pcl.${GUID} | $AWK '{ print $1 }')
   echo "PCL File Size after Conversion: ${SZ}" >> $LOG
   #
   # Send to Device via Java or native SMB client ...
   #
   echo "Sending `pwd`/out.pcl.${GUID} to the $PRINTER after Windows Print conversion..." >> $LOG
   if [ "${SMB_USAGE}" = "N" ]
   then
      nohup $JAVA_JRE -mx1024m unitask.oracle.apps.xxlpr.winutils.PrintDocumentHandler `pwd`/out.pcl.${GUID} $DB_USER $DB_PWD "$JDBC" $FORMATTED_PRINTER $CONF_FILE &
      #$JAVA_JRE -mx1024m unitask.oracle.apps.xxlpr.winutils.PrintDocumentHandler `pwd`/out.pcl.${GUID} $DB_USER $DB_PWD "$JDBC" $FORMATTED_PRINTER $CONF_FILE &
   else
      nohup cat `pwd`/out.pcl.${GUID} | smbclient "//${SMB_HOST}/${PRINTER}" -c "print -" -U ${SMB_USER}%${SMB_PASS} &
   fi # native or java client
   # 
   # Results ...
   #
   if [ "$?" = "0" ]
   then
      echo "File Printed" >> $LOG
   else
      echo "Error: $? " >> $LOG
      exit 1
   fi
   # 
   # Clean Up ...
   #
   if [ -e "`pwd`/out.ps.$GUID" ]
   then
      echo ""
      #rm `pwd`/out.ps.$GUID
   fi
   if [ -e "`pwd`/out.pcl.$GUID" ]
   then
      echo ""
      #rm `pwd`/out.pcl.$GUID 
   fi
fi;

#
# Handle PCL
#
if [ "$FILE_TYPE" = "PCL" ] && [ "$PRINTER_LANG" = "PCL" ]
then
   #
   # Send to Device via Java or native SMB client ...
   #
   echo "Sending $FILE to the $PRINTER without Windows Print conversion..." >> $LOG
   if [ "${SMB_USAGE}" = "N" ]
   then
      nohup $JAVA_JRE -mx1024m unitask.oracle.apps.xxlpr.winutils.PrintDocumentHandler $FILE $DB_USER $DB_PWD "$JDBC" $FORMATTED_PRINTER $CONF_FILE &
      #$JAVA_JRE -mx1024m unitask.oracle.apps.xxlpr.winutils.PrintDocumentHandler $FILE $DB_USER $DB_PWD "$JDBC" $FORMATTED_PRINTER $CONF_FILE &
   else
      nohup cat $FILE | smbclient "//${SMB_HOST}/${PRINTER}" -c "print -" -U ${SMB_USER}%${SMB_PASS} &
   fi # native or java client
   # 
   # Results ...
   #
   if [ "$?" = "0" ]
   then
      echo "File Printed" >> $LOG
   else
      echo "Error: $? " >> $LOG
      exit 1
   fi
fi;

# 
# PCL to PS ???
#
if [ "$FILE_TYPE" = "PCL" ] && [ "$PRINTER_LANG" = "PS" ]
then
   echo "" >> $LOG
   echo "PCL to PS file printing is not supported"  >> $LOG
   echo "" >> $LOG
   exit 1
fi;

# 
# The End ...
#

