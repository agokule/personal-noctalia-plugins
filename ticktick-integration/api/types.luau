--!nonstrict
-- Types for the TickTick Open API, as written in
-- https://developer.ticktick.com/docs/openapi.md: everything in its Definitions
-- section, plus the request bodies of the undone and completeTasks endpoints,
-- which the docs only describe inline.
--
-- Names drop the docs' "Open" prefix (OpenHabit → Habit). The focus and
-- comment types (OpenFocus, OpenFocusSummary, OpenPomodoroTaskBrief,
-- OpenComment) and Task.focusSummaries are deliberately left out.
--
-- The docs mark no field as required, and responses leave fields out freely
-- (GET /open/v1/habit returns only id, name, repeatRule and status), so most
-- fields are optional. The ones that aren't identify the record or are required
-- by its create endpoint.
--
-- Integers are plain numbers. Date-times are "yyyy-MM-dd'T'HH:mm:ssZ", though
-- some responses add milliseconds ("2026-03-05T00:00:00.000+0000"). Habit and
-- countdown dates are YYYYMMDD integers (20260407).

-- ── Tasks ───

-- A subtask. id is optional so that the same type works in a create body,
-- where items don't have one yet.
export type ChecklistItem = {
  id: string?,
  title: string,
  status: number?, -- 0 normal, 1 completed
  completedTime: string?, -- e.g. "2019-11-13T03:00:00+0000"
  isAllDay: boolean?, -- true when startDate carries no time of day
  sortOrder: number?, -- e.g. 234444
  startDate: string?, -- e.g. "2019-11-13T03:00:00+0000"
  timeZone: string?, -- e.g. "America/Los_Angeles"
}

-- described in https://developer.ticktick.com/docs/index.html#/openapi?id=task-1
-- Only title and projectId are required when creating a task; the server fills
-- in the rest, so everything else is optional here.
export type Task = {
  id: string?,
  projectId: string, -- the project the task is in
  title: string,
  content: string?, -- the task's body text
  desc: string?, -- the description of a checklist task
  isAllDay: boolean?, -- true when the dates carry no time of day
  startDate: string?, -- "yyyy-MM-dd'T'HH:mm:ssZ", e.g. "2019-11-13T03:00:00+0000"
  dueDate: string?, -- e.g. "2019-11-14T03:00:00+0000"
  timeZone: string?, -- e.g. "America/Los_Angeles"
  reminders: {string}?, -- "TRIGGER:..." entries, e.g. { "TRIGGER:P0DT9H0M0S", "TRIGGER:PT0S" }
  tags: {string}?, -- e.g. { "work", "urgent" }
  repeatFlag: string?, -- an RRULE, e.g. "RRULE:FREQ=DAILY;INTERVAL=1"
  -- How a repeating task finds its next date; only read alongside repeatFlag.
  --   "0"  from the original due or start date
  --   "1"  from the completion date, keeping the original time of day
  --   "2"  by the calendar in the task's time zone, skipping occurrences that
  --        have already passed (the server's default)
  repeatFrom: string?,
  priority: number?, -- 0 none, 1 low, 3 medium, 5 high
  status: number?, -- -1 abandoned, 0 normal, 2 completed
  completedTime: string?, -- e.g. "2019-11-13T03:00:00+0000"
  sortOrder: number?, -- e.g. 12345
  items: {ChecklistItem}?, -- subtasks
  parentId: string?, -- the parent task's id; "" removes the task from its parent
  assigneeUsername: string?, -- the project member the task is assigned to
  etag: string?, -- entity tag, e.g. "t3kc5m5f"
  kind: string?, -- "TEXT" a plain task, "CHECKLIST" one with subtasks, "NOTE" a note
}

-- Body of POST /open/v1/task/undone, which responds with {Task}: the
-- undone tasks in a date range of at most 14 days. An invalid range gets an
-- empty array, not an error.
export type UndoneTasksBody = {
  -- Projects to search, with "inbox" for the inbox. Omitted, every project the
  -- user can access is searched.
  projectIds: {string}?,
  taskIds: {string}?, -- only return these tasks
  startDate: string, -- start of the range, e.g. "2026-07-01T00:00:00+0000"
  endDate: string, -- end of the range, not before startDate, e.g. "2026-07-14T23:59:59+0000"
}

-- Body of POST /open/v1/task/filter, which responds with {Task}: at most 200
-- tasks that match every filter given.
export type FilterTasksBody = {
  projectIds: {string}?, -- only tasks in these projects
  startDate: string?, -- only tasks whose startDate is at or after this
  endDate: string?, -- only tasks whose startDate is at or before this
  priority: {number}?, -- only these priorities: 0 none, 1 low, 3 medium, 5 high
  tag: {string}?, -- only tasks that have all of these tags
  kind: {string}?, -- only these kinds: "TEXT", "NOTE", "CHECKLIST"
  status: {number}?, -- only these statuses, e.g. { 0 } for open, { 2 } for completed
}

-- Body of POST /open/v1/task/completeTasks, which completes tasks of one
-- project and responds with the ids it completed ({string}).
export type CompleteTasksBody = {
  projectId: string?, -- the tasks' project; omitted or "" means the inbox
  taskIds: {string}, -- tasks to complete; only the first 50 are processed
}

-- ── Projects ───

export type Project = {
  id: string,
  name: string,
  color: string?, -- "#F18181"
  sortOrder: number?, -- order value, e.g. 0
  closed: boolean?, -- whether the project is closed (archived)
  groupId: string?, -- a ProjectGroup id
  viewMode: string?, -- "list", "kanban" (columns) or "timeline"
  -- The user's access to a shared project: "read" to view only, "write" to
  -- edit, "comment" to view and comment.
  permission: string?,
  kind: string?, -- "TASK" a list of tasks, "NOTE" a list of notes
}

-- A kanban column of a project.
export type Column = {
  id: string,
  projectId: string, -- the project the column is in
  name: string, -- at most 1000 chars
  sortOrder: number?, -- order value, e.g. 0
}

-- GET /open/v1/project/{projectId}/data
export type ProjectData = {
  project: Project,
  tasks: {Task}, -- the project's undone tasks only
  columns: {Column}, -- the project's kanban columns
}

-- A folder of projects.
export type ProjectGroup = {
  id: string,
  name: string, -- at most 64 chars
  sortOrder: number?, -- e.g. 0
  showAll: boolean?, -- whether to show all projects in the group
  viewMode: string?, -- "list", "kanban" (columns) or "timeline"
}

-- ── Tags ───

export type Tag = {
  name: string, -- lowercase and trimmed, at most 64 chars, e.g. "work"
  label: string, -- the displayed name; must equal name once lowercased
  sortOrder: number?, -- e.g. 0
  color: string?, -- e.g. "#F18181"
  parent: string?, -- the parent tag's name
  type: number?, -- 1 personal, 2 team (shared)
}

-- ── Habits ───

export type Habit = {
  id: string,
  name: string, -- at most 1000 chars, e.g. "Read"
  iconRes: string?, -- icon resource, e.g. "habit_reading"
  color: string?, -- e.g. "#4D8CF5"
  sortOrder: number?, -- e.g. 12345
  status: number?, -- e.g. 0; the docs list no values
  encouragement: string?, -- encouragement message, e.g. "Keep going"
  totalCheckIns: number?, -- e.g. 12
  createdTime: string?, -- e.g. "2024-01-01T00:00:00+0000"
  modifiedTime: string?, -- e.g. "2024-01-08T00:00:00+0000"
  archivedTime: string?, -- e.g. "2024-01-08T00:00:00+0000"
  type: string?, -- e.g. "Boolean"; the docs list no other values
  goal: number?, -- e.g. 1.0
  step: number?, -- e.g. 1.0
  unit: string?, -- e.g. "Count"
  etag: string?, -- entity tag
  repeatRule: string?, -- an RRULE, e.g. "RRULE:FREQ=DAILY;INTERVAL=1"
  reminders: {string}?, -- habit reminders
  recordEnable: boolean?, -- whether record is enabled
  sectionId: string?, -- a HabitSection id
  targetDays: number?, -- target days, e.g. 0
  targetStartDate: number?, -- YYYYMMDD, e.g. 20240101
  completedCycles: number?, -- e.g. 12
  exDates: {string}?, -- excluded dates
  style: number?, -- e.g. 0; the docs list no values
}

-- A group of habits.
export type HabitSection = {
  id: string,
  name: string, -- e.g. "Health"
  sortOrder: number?, -- e.g. 12345
  createdTime: string?, -- e.g. "2026-07-01T00:00:00+0000"
  modifiedTime: string?, -- last modification, e.g. "2026-07-01T00:00:00+0000"
  etag: string?, -- entity tag
}

-- One day's check-in. Also the body of POST /open/v1/habit/{habitId}/checkin,
-- which requires only stamp.
export type HabitCheckinData = {
  id: string?, -- absent from the docs' example responses
  stamp: number, -- the day, YYYYMMDD, e.g. 20260407
  time: string?, -- check-in time, e.g. "2026-04-07T08:00:00+0000"
  opTime: string?, -- operation time, e.g. "2026-04-07T08:00:00+0000"
  value: number?, -- defaults to 1.0
  goal: number?, -- defaults to 1.0
  status: number?, -- the docs list no values
}

-- One habit's check-ins for one year.
export type HabitCheckin = {
  id: string?, -- the check-in document's id; absent from the docs' example responses
  habitId: string,
  createdTime: string?, -- e.g. "2026-04-07T08:00:00+0000"
  modifiedTime: string?, -- e.g. "2026-04-07T08:00:00+0000"
  etag: string?, -- entity tag
  year: number, -- e.g. 2026
  checkins: {HabitCheckinData},
}

-- ── Countdowns ───

-- The docs describe most of these fields by name alone. The numeric ones (type,
-- showCalendarType, annoyingAlert, status, timerMode, daysOption) look like
-- enums, but the docs list none of their values.
export type Countdown = {
  id: string,
  type: number?, -- e.g. 0
  iconRes: string?, -- icon resource
  color: string?, -- e.g. "#4D8CF5"
  name: string, -- e.g. "Birthday"
  date: number?, -- YYYYMMDD, e.g. 20260407
  ignoreYear: boolean?, -- whether to ignore the year
  showCalendarType: number?,
  reminders: {string}?,
  annoyingAlert: number?,
  repeatFlag: string?, -- an RRULE, e.g. "RRULE:FREQ=DAILY;INTERVAL=1"
  remark: string?,
  status: number?,
  sortOrder: number?, -- e.g. 0
  style: string?,
  styleColor: {string}?, -- style colors
  dateDisplayFormat: string?,
  timerMode: number?,
  showAge: boolean?, -- whether to show the age
  daysOption: number?,
  showRemark: boolean?, -- whether to show the remark
  createdTime: string?, -- e.g. "2024-01-01T00:00:00+0000"
  modifiedTime: string?, -- e.g. "2024-01-08T00:00:00+0000"
}

return {}
