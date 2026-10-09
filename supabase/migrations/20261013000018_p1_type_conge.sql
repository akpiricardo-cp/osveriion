-- =============================================================================
-- VERIION OS — Migration 18 : les congés deviennent un circuit de décision
-- =============================================================================
-- Fichier séparé : une nouvelle valeur d'énumération ne peut pas être utilisée
-- dans la transaction qui la crée.
alter type public.approval_kind add value if not exists 'leave';
