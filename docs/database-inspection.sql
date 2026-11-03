-- Read-only inspection. Run before preparing any migration for an existing project.
SELECT table_schema, table_name FROM information_schema.tables
WHERE table_schema NOT IN ('pg_catalog','information_schema') ORDER BY 1,2;
SELECT table_name,column_name,data_type,is_nullable,column_default FROM information_schema.columns
WHERE table_schema='public' ORDER BY table_name,ordinal_position;
SELECT schemaname,tablename,policyname,roles,cmd,qual,with_check FROM pg_policies WHERE schemaname IN ('public','storage');
SELECT tablename,rowsecurity FROM pg_tables WHERE schemaname='public';
SELECT id,name,public FROM storage.buckets;
SELECT routine_name, data_type FROM information_schema.routines WHERE routine_schema='public';
