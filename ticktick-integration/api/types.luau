export type TicktickProject = {
  id: string,
  name: string,
  color: string,
  closed: boolean,
  groupId: string,
  viewMode: string,
  permission: string,
  kind: string
}

-- described in https://developer.ticktick.com/docs/index.html#/openapi?id=task-1
-- Only title and projectId are required when creating a task; the server fills
-- in the rest, so everything else is optional here.
export type TicktickTask = {
  id: string?,
  projectId: string,
  title: string,
  content: string?,
  desc: string?,
  isAllDay: boolean?,
  startDate: string?, -- "yyyy-MM-dd'T'HH:mm:ssZ"
  dueDate: string?,
  timeZone: string?,
  reminders: {string}?, -- "TRIGGER:..." entries
  tags: {string}?,
  repeatFlag: string?, -- "RRULE:..."
  priority: number?, -- 0 none, 1 low, 3 medium, 5 high
  status: number?, -- -1 abandoned, 0 normal, 2 completed
  completedTime: string?,
  sortOrder: number?,
  etag: string?,
  kind: string?, -- "TEXT", "NOTE", "CHECKLIST"
}

return {}
