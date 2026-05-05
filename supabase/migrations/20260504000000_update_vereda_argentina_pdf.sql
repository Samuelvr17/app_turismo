-- Migration: Update PDF URL for Vereda Argentina
-- Replaces the test PDF (Modelos-de-Calidad-del-Software.pdf) with the official one.
UPDATE safe_routes
SET pdf_url = 'https://mxkdkfihshfbsvazmftg.supabase.co/storage/v1/object/public/route-pdfs/VeredaArgentina/ficha-caracterizacion-vereda-argentina.pdf'
WHERE name = 'Vereda Argentina';
