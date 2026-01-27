---
description: Verify Academy Schedule Feature
---

1. [ ] **DailyAttendanceScreen UI**
   - Check if the toggle "학원 휴강 설정" (Set Academy Holiday) appears below the calendar.
   - Select a date and toggle the switch ON.
   - Verify that the calendar date number turns red or has a marker.
   - Verify that the right-side attendance table is replaced by the "Day Off" overlay message.
   - Toggle the switch OFF and verify the table returns.

2. [ ] **Data Persistence**
   - Refresh the page or restart the app.
   - Go back to the date you marked as a holiday.
   - Verify it is still marked as a holiday.

3. [ ] **Monthly Attendance Rate** (After implementing AttendanceScreen changes)
   - Note the attendance rate for a student.
   - Mark a class day as "Holiday".
   - Verify the denominator decreases by 1 (e.g., 8/8 -> 7/7).
