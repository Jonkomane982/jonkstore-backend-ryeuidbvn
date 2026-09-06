-- 001_extensions.sql
-- SQLite Database Configuration for JonkStore POS
-- Principal Database Architect: Production Grade

-- Enable Foreign Key constraints
PRAGMA foreign_keys = ON;

-- Use Write-Ahead Logging for better concurrency and performance
PRAGMA journal_mode = WAL;

-- Set synchronous to NORMAL for a good balance between safety and speed
PRAGMA synchronous = NORMAL;

-- Optimize the database by reclaiming unused space
PRAGMA auto_vacuum = INCREMENTAL;

-- Set the encoding to UTF-8
PRAGMA encoding = 'UTF-8';
