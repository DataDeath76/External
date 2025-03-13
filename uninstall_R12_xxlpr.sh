#!/bin/ksh
# $Id:uninstall_R12_xxlpr.sh 134 2006-04-03 13:59:04 +0300 valeryk $
# Copyright 1998-2006, Unitask, Inc., All rights reserved.

check_password()
{
CUSER=$1
CPSWD=$2
X=`sqlplus -s $CUSER/$CPSWD << EOF
exit
/
EOF
`

X=`echo $X | grep 01017 | wc -l`
return $X
}

input_password()
{
USER_PROMPT=$1
PASS_PROMPT=$2
IDEFUSER=$3
IDEFPWD=$4

i="1"
while [ $i -le 5 ]
do
  echo "$1(default: $IDEFUSER)"
  # Added following line to suppress echo of password
  stty -echo
  read IUSER
  stty echo
  if [ "$IUSER" = "" ]
  then
    IUSER=$3
  fi
  echo "$2(default: $IDEFPWD)"
  # Added following line to suppress echo of password
  stty -echo
  read IPSWD
  # Added following line to restore echo of input
  stty echo
  if [ "$IPSWD" = "" ]
  then
    IPSWD=$4
  fi
  check_password $IUSER $IPSWD
  if [ $? -eq 0 ]
  then
    # Added following line to acknowledge that password is accepted
    echo "Password accepted."
    return 0
  fi
  echo "Incorrect password. Please try again."
i=`expr $i + 1`
done
echo "Incorrect password. The installation process was terminated."
exit
return 1
}

# Menu
echo ""
echo "   --------------------------------------------------"
echo "            Unitask Output Director"
echo "   --------------------------------------------------"
echo ""
echo "   1.    Generate Environment File for uninstallation (uninstall_xxlpr_`hostname`.env)"
echo ""
echo "   2.    Uninstall with Generated Environment File "
echo ""
echo "   3.    Generate Environment File and Uninstall"
echo ""
echo "   4.    Exit"
echo ""
echo "Enter your choice [3] :"
read CHOICE

if [ "$CHOICE" = "" ]
then
  CHOICE=3
fi

if [ $CHOICE -eq 4 ]
then
  exit
fi

echo "Enter the Tier. Tier can be (A)pplication, (B)oth or (C)oncurrent Manager"
read TIER
TIER=`echo $TIER  | tr 'a-z' 'A-Z'` 

#  apps password-----
input_password "Enter Apps user" "Enter Apps Password" apps apps
APPS_USER=$IUSER
APPS_PWD=$IPSWD
export APPS_USER
export APPS_PWD

case $TIER in 
B|C)  
  # System Password
  input_password "Enter System User" "Enter System Password" system manager
  SYSTEM_USER=$IUSER
  SYSTEM_PASS=$IPSWD
export SYSTEM_USER  
export SYSTEM_PASS
;;
esac

case $CHOICE in
1)
  ./cre_R12_env_file.sh $APPS_USER $APPS_PWD "./uninstall_xxlpr_`hostname`.env" $TIER XXLPR
  echo "Environment file was created"
  exit
;;
2) :
;;
3)
  ./cre_R12_env_file.sh $APPS_USER $APPS_PWD "./uninstall_xxlpr_`hostname`.env" $TIER XXLPR "NO"
;;
4)
  echo "Installation was canceled."
  exit
;;
esac

echo "Reading environment file."
. ./uninstall_xxlpr_`hostname`.env
INSTALL_DIR=`pwd`
echo "###--------- $TIER CM Tier "
cd $INSTALL_DIR
pwd
rm *.log
> ${0}.log
(

cd $INSTALL_DIR
case $TIER in 
B|C)

echo Removing plugin from all users.
$SQLPLUS $APPS_USER/${APPS_PWD} @$XXLPR_TOP/sql/add_uod_plugin.sql DELETE ALL_USERS Y


   # delete tables and packages
   echo "###---------  DB/system"
   $SQLPLUS <<!!
$SYSTEM_USER/${SYSTEM_PASS}
select instance_name from v\$instance
/
grant dba to ${XX_USER}
/
grant JAVASYSPRIV to apps
/
!!


$SQLPLUS $APPS_USER/${APPS_PWD} @$INSTALL_DIR/remove_apps_objects.sql
   
echo "Revoking grants from ${XX_USER} user."
$SQLPLUS <<!!
$SYSTEM_USER/${SYSTEM_PASS}
revoke dba from ${XX_USER}
/
!!


L_OWNER=`$SQLPLUS <<!!
$SYSTEM_USER/${SYSTEM_PASS}
set define off 
set head off 
set verify off 
select owner from all_tables t
where t.table_name = 'UNITASK_PRODUCT_LICENSES'
/
!!
`

L_OWNER=`echo $L_OWNER`
echo "UNITASK_PRODUCT_LICENSES owner:$L_OWNER"
if [ "$L_OWNER" != "$XX_USER" ]
then
echo "Dropping user $XX_USER"
$SQLPLUS <<!!
system/${SYSTEM_PASS}
drop user $XX_USER cascade
/
!!
fi

   cd $INSTALL_DIR
   echo "Deleting profiles, menus, functions, responsibilities and application"
$SQLPLUS <<!!
$APPS_USER/${APPS_PWD}
begin
   for profile_rec in ( select p.profile_option_name, p.profile_option_id
                     from fnd_profile_options p
                     where profile_option_name like 'XXLPR%') loop
     delete fnd_profile_option_values a
     where  a.profile_option_id = profile_rec.profile_option_id;
                     
     fnd_profile_options_pkg.delete_row(x_profile_option_name => profile_rec.profile_option_name);
   end loop;                                             

   for menu_entry_rec in ( select b.menu_id, b.entry_sequence
                           from   fnd_menus a,fnd_menu_entries b
                           where  a.menu_name like 'XXLPR%'
                           and    a.menu_id = b.menu_id) loop
      fnd_menu_entries_pkg.delete_row(x_menu_id => menu_entry_rec.menu_id,
                                      x_entry_sequence => menu_entry_rec.entry_sequence);
   end loop; 


   for function_rec in ( select f.function_id
                         from   fnd_form_functions f
                         where  function_name like 'XXLPR%') loop
     fnd_form_functions_pkg.delete_row(x_function_id => function_rec.function_id); 
   end loop;                                           
 
   for menu_rec in ( select m.menu_id
                     from   fnd_menus m
                     where  m.menu_name like 'XXLPR%') loop
     fnd_menus_pkg.DELETE_ROW(x_menu_id => menu_rec.menu_id);
   end loop;  

   for resp_rec in (SELECT fu.user_name,
             fa.application_short_name,
             frt.responsibility_name,
             fr.responsibility_key,
             fsg.security_group_key
        FROM fnd_user_resp_groups_all ful,
             fnd_user fu,
             fnd_responsibility_tl frt,
             fnd_responsibility fr,
             fnd_security_groups fsg,
             fnd_application fa
       WHERE     fu.user_id = ful.user_id
             AND frt.responsibility_id = ful.responsibility_id
             AND fr.responsibility_id = frt.responsibility_id
             AND fsg.security_group_id = ful.security_group_id
             AND fa.application_id = ful.responsibility_application_id
             AND UPPER(fr.responsibility_key) like 'XXLPR%') loop
     fnd_user_pkg.delresp (username         => resp_rec.user_name,
                               resp_app         => resp_rec.application_short_name,
                               resp_key         => resp_rec.responsibility_key,
                               security_group   => resp_rec.security_group_key);  
   end loop;

   for appl_rec in (select application_id from fnd_application where application_short_name = 'XXLPR') loop
    begin
     delete from fnd_data_group_units where application_id = appl_rec.application_id; 
     FND_APPLICATION_PKG.DELETE_ROW(X_APPLICATION_ID => appl_rec.application_id);
    exception
         when OTHERS
          then 
            null;
    end;
   end loop; 

   update fnd_concurrent_programs c 
   set c.enabled_flag = 'N' 
   where c.concurrent_program_name like 'XXLPR%';

   commit;
end;
/
!!


   ;;
esac
cd $INSTALL_DIR
#---------  Applications Tier
case $TIER in
A|B)

   echo "###---------  Applications Tier"

   # Delete files from OA_JAVA
   cd $OA_JAVA
   rm -rf xxlpr* 1> /dev/null 2> /dev/null

   echo "Deleting xxlpr controller directory and copying contents."
   cd $OA_JAVA/oracle/apps/
   rm -rf xxlpr 1> /dev/null 2> /dev/null   
   rm -rf $OA_JAVA/unitask/localPrint 1> /dev/null 2> /dev/null   
   
   echo "Deleting Framework Screens"
   rm -rf $OA_JAVA/unitask/oracle/apps/xxlpr 1> /dev/null 2> /dev/null
   
   echo "Deleting OA_HTML/xxlpr directory and copying contents."
   cd $OA_HTML
   rm -rf xxlpr 1> /dev/null 2> /dev/null
   
   echo "Deleting OA_MEDIA/xxlpr directory and removing contents."
   cd $OA_MEDIA
   rm -rf xxlpr 1> /dev/null 2> /dev/null
   rm xxlpr_logo.jpg 1> /dev/null 2> /dev/null

;; # case A or B
esac
) | tee  ${0}.log 2>&1

   echo "Deleting XXLPR_TOP directories."
   cd $XXLPR_PATH
   rm -rf xxlpr 1> /dev/null 2> /dev/null
   
   echo ""
   echo "If you personalized OAF Home-Page, personalization should be removed manually"
   echo ""

case $TIER in
B|C)
echo " "
echo "Attention: Must Restart Concurrent Manager"
;;
esac
case $TIER in
A|B)
echo " "
echo "Attention: Must Restart Web Server"
echo " " 
;;
esac


