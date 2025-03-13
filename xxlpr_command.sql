REM $Id: xxlpr_command.sql 1549 2010-12-14 15:37:11Z mshapira $
REM Copyright Unitask Inc., 1999-2010
set head off
set line 150
set wrap off
set verify off
set feedback off
select nvl(fnd_profile.VALUE_specific('XXLPR_'||'&1',fcr.requested_by),fnd_profile.VALUE_specific('XXLPR_LOCAL_PRINTTO',fcr.requested_by))
from   fnd_concurrent_requests fcr
where  request_id=to_number('&2')
/
exit
