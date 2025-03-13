REM $Id: remove_apps_objects.sql 1418 2010-06-23 15:32:30Z mshapira $
REM Copyright Unitask Inc., 1999-2009. All Rights Reserved
set serveroutput on
set line 150
begin
   for rec in (select owner, object_name, object_type
                 from all_objects
                where object_name like 'XXLPR%' 
                and   object_type in
                      ('PACKAGE', 'SYNONYM', 'VIEW', 'TABLE', 'SEQUENCE','TRIGGER')
                /*and   owner='APPS'*/
                and   object_name <> 'UNITASK_PRODUCT_LICENSES')       loop
    begin
       dbms_output.put_line('drop ' || rec.object_type || ' ' || rec.owner || '.' ||rec.object_name);
       execute immediate 'drop ' || rec.object_type || ' ' || rec.owner || '.' ||rec.object_name;
    exception
       when others then
          dbms_output.put_line(sqlerrm);
    end;
   end loop;
end;
/
exit
