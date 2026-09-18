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

export type TicktickTask = {
  id: string,
  projectId: string,
  sortOrder: number,
  title: string,
  content: string,
  timeZone: string,
  isAllDay: boolean,
  priority: number,
  completedTime: string,
  status: number,
  etag: string,
  kind: string
}

return {}

