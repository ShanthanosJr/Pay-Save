-- Seettu rule: the member who receives a cycle's payout does not contribute
-- in that cycle. The payout is what the OTHER members paid, so every total is
-- backed by real recorded payments and nobody "pays themself".
-- Also: a contribution becomes overdue at midnight in Sri Lanka, not UTC.

CREATE OR REPLACE VIEW v_cycle_member_status AS
WITH contrib AS (
  SELECT e.cycle_id, e.subject_user_id, e.id, e.amount_minor, e.reference, e.created_at
  FROM ledger_entries e
  WHERE e.entry_type = 'contribution_recorded'
    AND NOT EXISTS (SELECT 1 FROM ledger_entries c
                    WHERE c.entry_type = 'correction' AND c.target_entry_id = e.id)
),
verified AS (
  SELECT v.target_entry_id AS contribution_id, max(v.created_at) AS verified_at
  FROM ledger_entries v WHERE v.entry_type = 'contribution_verified'
  GROUP BY v.target_entry_id
)
SELECT cy.circle_id, cy.id AS cycle_id, cy.number AS cycle_number, cm.user_id,
       c.id AS contribution_id, c.reference, c.amount_minor,
       c.created_at AS recorded_at, v.verified_at,
       CASE
         WHEN v.verified_at IS NOT NULL THEN 'verified'
         WHEN c.id IS NOT NULL          THEN 'recorded'
         WHEN cy.due_date < (now() AT TIME ZONE 'Asia/Colombo')::date THEN 'overdue'
         ELSE 'due'
       END AS status
FROM cycles cy
JOIN circle_members cm ON cm.circle_id = cy.circle_id
     AND cm.role IN ('member', 'organizer')
     AND cm.joined_cycle <= cy.number
     AND (cm.left_cycle IS NULL OR cm.left_cycle > cy.number)
LEFT JOIN contrib  c ON c.cycle_id = cy.id AND c.subject_user_id = cm.user_id
LEFT JOIN verified v ON v.contribution_id = c.id
-- the receiver owes nothing this cycle; a payment they recorded before this
-- rule existed stays visible so old totals still add up
WHERE cm.user_id IS DISTINCT FROM cy.payout_user_id OR c.id IS NOT NULL;
