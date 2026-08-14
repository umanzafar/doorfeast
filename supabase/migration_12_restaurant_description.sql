-- DoorFeast — Migration 12: restaurant description field
-- Run after migration_11.

alter table restaurants add column description text;
