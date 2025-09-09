-- Example queries

-- List all properties
SELECT code, name FROM properties ORDER BY code;

-- List rooms in Melbourne
SELECT room_no, room_type FROM rooms
WHERE property_id='20000000-0000-0000-0000-000000000001';

-- Count tasks per property
SELECT p.code, t.status, COUNT(*) AS cnt
FROM tasks t
JOIN properties p USING (property_id)
GROUP BY p.code, t.status;
