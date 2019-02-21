GRANT EXECUTE ON FUNCTION dblink_connect_u(text) TO postgres;
GRANT EXECUTE ON FUNCTION dblink_connect_u(text, text) TO postgres;
UPDATE pg_database SET datistemplate = FALSE WHERE datname = 'template1';
DROP DATABASE template1;
CREATE DATABASE template1 WITH TEMPLATE = template0 ENCODING = 'UNICODE';
UPDATE pg_database SET datistemplate = TRUE WHERE datname = 'template1';
VACUUM FREEZE;