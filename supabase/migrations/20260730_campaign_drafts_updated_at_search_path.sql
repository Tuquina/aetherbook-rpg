-- Closes the linter's "function_search_path_mutable" warning on
-- set_updated_at() (introduced by its own migration), same fix as
-- 20260728_reading_stats_search_path.sql applied to reading_stats().
alter function set_updated_at() set search_path = public;
