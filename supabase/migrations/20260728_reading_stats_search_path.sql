-- Closes the linter's "function_search_path_mutable" warning on
-- reading_stats() (introduced by its own migration) — pins search_path so
-- it can't be hijacked by a role-local search_path change, standard
-- hardening for any SQL/plpgsql function.
alter function reading_stats() set search_path = public;
