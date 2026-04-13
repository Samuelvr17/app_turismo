-- Migration to add pdf_url to safe_routes table
ALTER TABLE safe_routes ADD COLUMN IF NOT EXISTS pdf_url TEXT;
