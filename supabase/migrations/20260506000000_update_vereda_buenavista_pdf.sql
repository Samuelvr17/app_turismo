-- Migration: Update PDF URL for Vereda Buenavista
-- Replaces GUIA_RAPIDA_IMPLEMENTACION.pdf with Ficha-caracterizacion-vereda-buenavista.pdf
UPDATE safe_routes
SET pdf_url = 'https://mxkdkfihshfbsvazmftg.supabase.co/storage/v1/object/public/route-pdfs/VeredaBuenaVista/Ficha-caracterizacion-vereda-buenavista.pdf'
WHERE name = 'Vereda Buenavista';
