const API_URL = import.meta.env.VITE_API_URL ?? 'http://localhost:4000/api';

export type AuthUser = {
  id: string;
  email: string;
  displayName: string;
  username: string;
  role: 'USER' | 'CREATOR' | 'ADMIN';
  avatarUrl: string | null;
};

export type AuthResponse = {
  accessToken: string;
  tokenType: 'Bearer';
  expiresIn: string;
  user: AuthUser;
};

export type AdminUser = {
  id: string;
  email: string;
  displayName: string;
  username: string;
  avatarUrl: string | null;
  bio: string | null;
  role: AuthUser['role'];
  isActive: boolean;
  lastLatitude: number | null;
  lastLongitude: number | null;
  locationSource: string | null;
  locationUpdatedAt: string | null;
  createdAt: string;
  subscriptions: Array<{
    id: string;
    status: string;
    provider: 'REVENUECAT';
    externalSubscriptionId: string | null;
    externalProductId: string | null;
    latestEventAt: string | null;
    canceledAt: string | null;
    expiresAt: string;
    plan: SubscriptionPlan;
  }>;
  _count: {
    followers: number;
    following: number;
    videos: number;
    reels: number;
  };
};

export type LocationInsights = {
  locatedUsers: number;
  totalLocationPings: number;
  topLocations: Array<{
    latitude: number;
    longitude: number;
    users: number;
    pings: number;
    lastSeenAt: string;
  }>;
};

export type CreateUserInput = {
  email: string;
  password: string;
  displayName: string;
  username: string;
  role: 'USER' | 'CREATOR';
};

export type UpdateUserInput = {
  email?: string;
  password?: string;
  displayName?: string;
  username?: string;
  bio?: string;
  role?: 'USER' | 'CREATOR';
};

export type AdminReport = {
  id: string;
  targetType: string;
  targetId: string;
  targetLabel: string;
  targetUrl: string | null;
  reason: string;
  status: string;
  createdAt: string;
  reporter: {
    id: string;
    displayName: string;
    username: string;
    email: string;
  };
  subjectUser: {
    id: string;
    displayName: string;
    username: string;
    email: string;
  } | null;
};

export type ReportStatusFilter = 'ALL' | 'OPEN' | 'REVIEWING' | 'RESOLVED' | 'REJECTED';
export type ReportAction = 'MARK_REVIEWING' | 'DISMISS' | 'BLOCK_CONTENT' | 'BLOCK_USER';

export type AdminLiveRoom = {
  id: string;
  title: string;
  status: string;
  commentsOn: boolean;
  recordingOn: boolean;
  currentViewerCount: number;
  peakViewerCount: number;
  totalViewerJoins: number;
  uniqueViewerCount: number;
  startedAt: string | null;
  endedAt: string | null;
  createdAt: string;
  hostName: string;
  durationSeconds: number;
  host: {
    id: string;
    displayName: string;
    username: string;
    email: string;
  };
  recordings: Array<{
    id: string;
    egressId: string | null;
    objectKey: string | null;
    publicUrl: string | null;
    status: string;
    errorMessage: string | null;
    startedAt: string | null;
    endedAt: string | null;
    createdAt: string;
  }>;
  _count: {
    comments: number;
    reactions: number;
    recordings: number;
  };
};

export type AdminFeedItem = {
  id: string;
  feedType: 'VIDEO' | 'REEL';
  label: string;
  title?: string;
  caption?: string | null;
  description?: string | null;
  status: string;
  commentsEnabled: boolean;
  viewCount: number;
  createdAt: string;
  creator: {
    id: string;
    displayName: string;
    username: string;
    email: string;
  };
  mediaAsset: {
    id: string;
    publicUrl: string | null;
    durationMs: number | null;
  };
  thumbnail: {
    id: string;
    publicUrl: string | null;
  } | null;
  _count: {
    comments: number;
    likes: number;
    dislikes: number;
    shares: number;
  };
};

export type AdminAuditLog = {
  id: string;
  adminId: string;
  action: string;
  target: string;
  metadata: unknown;
  createdAt: string;
  admin: {
    id: string;
    displayName: string;
    username: string;
    email: string;
  };
};

export type AuditLogFilters = {
  action?: string;
  adminId?: string;
  target?: string;
};

export type LiveParticipant = {
  identity: string;
  userId: string;
  user: {
    id: string;
    displayName: string;
    username: string;
    avatarUrl: string | null;
  } | null;
};

export type LiveBlockedViewer = {
  id: string;
  userId: string;
  createdAt: string;
  user: {
    id: string;
    displayName: string;
    username: string;
    avatarUrl: string | null;
  } | null;
};

export type SubscriptionPlan = {
  id: string;
  name: string;
  description: string | null;
  priceCents: number;
  currency: string;
  durationDays: number;
  revenueCatOfferingId: string | null;
  revenueCatPackageId: string | null;
  revenueCatEntitlementId: string | null;
  isActive: boolean;
  createdAt: string;
  updatedAt: string;
};

export type PlanInput = {
  name: string;
  description?: string;
  priceCents: number;
  currency: string;
  durationDays: number;
  revenueCatOfferingId?: string;
  revenueCatPackageId?: string;
  revenueCatEntitlementId?: string;
  isActive: boolean;
};

export type PaymentEvent = {
  id: string;
  provider: 'REVENUECAT';
  eventId: string;
  eventType: string;
  userId: string | null;
  subscriptionId: string | null;
  processedAt: string;
  createdAt: string;
  user: {
    id: string;
    displayName: string;
    username: string;
    email: string;
  } | null;
};

export type StorageSettings = {
  id: string;
  provider: 'LOCAL' | 'R2';
  localBasePath: string;
  localPublicUrl: string;
  videoCompressionEnabled: boolean;
  r2Bucket: string | null;
  r2Endpoint: string | null;
  r2Region: string | null;
  r2AccessKeyId: string | null;
  r2SecretConfigured: boolean;
  r2PublicUrl: string | null;
  updatedAt: string;
};

export type StorageHealth = {
  provider: 'LOCAL' | 'R2';
  healthy: boolean;
  writable: boolean;
  publicUrl: string | null;
  message?: string;
  checkedAt: string;
};

export type StorageCleanupResult = {
  provider: 'LOCAL' | 'R2';
  dryRun: boolean;
  candidates: number;
  deleted: number;
  message?: string;
  checkedAt?: string;
};

export type StorageSettingsInput = {
  provider?: 'LOCAL' | 'R2';
  localBasePath?: string;
  localPublicUrl?: string;
  videoCompressionEnabled?: boolean;
  r2Bucket?: string;
  r2Endpoint?: string;
  r2Region?: string;
  r2AccessKeyId?: string;
  r2SecretKey?: string;
  r2PublicUrl?: string;
};

export type MediaProcessingJob = {
  id: string;
  type: string;
  status: string;
  attempts: number;
  maxAttempts: number;
  errorMessage: string | null;
  startedAt: string | null;
  completedAt: string | null;
  createdAt: string;
  mediaAsset: {
    id: string;
    objectKey: string;
    publicUrl: string | null;
    contentType: string;
    sizeBytes: number | null;
  };
  video: {
    id: string;
    title: string;
    status: string;
  } | null;
  reel: {
    id: string;
    caption: string | null;
    status: string;
  } | null;
  liveRecording: {
    id: string;
    status: string;
    room: {
      id: string;
      title: string;
    };
  } | null;
};

export async function loginAdmin(input: { email: string; password: string }) {
  return authRequest('/auth/login', input);
}

export async function getDashboard() {
  return adminRequest<{
    users: number;
    videos: number;
    reels: number;
    pendingReports: number;
    activeLiveRooms: number;
  }>('/admin/dashboard');
}

export function getUsers() {
  return adminRequest<AdminUser[]>('/admin/users');
}

export function createUser(input: CreateUserInput) {
  return adminRequest<AdminUser>('/admin/users', {
    method: 'POST',
    body: JSON.stringify(input)
  });
}

export function updateUser(id: string, input: UpdateUserInput) {
  return adminRequest<AdminUser>(`/admin/users/${id}`, {
    method: 'PATCH',
    body: JSON.stringify(input)
  });
}

export function getReports(status: ReportStatusFilter = 'ALL') {
  return adminRequest<AdminReport[]>(`/admin/reports?status=${status}`);
}

export function updateReportStatus(id: string, status: string) {
  return adminRequest<AdminReport>(`/admin/reports/${id}`, {
    method: 'PATCH',
    body: JSON.stringify({ status })
  });
}

export function actionReport(id: string, action: ReportAction) {
  return adminRequest<AdminReport>(`/admin/reports/${id}/actions`, {
    method: 'POST',
    body: JSON.stringify({ action })
  });
}

export type FeedStatusFilter = 'ACTIVE' | 'PUBLISHED' | 'BLOCKED' | 'DELETED';

export function getFeedItems(status: FeedStatusFilter = 'ACTIVE') {
  return adminRequest<AdminFeedItem[]>(`/admin/feed-items?status=${status}`);
}

export function updateFeedItem(type: 'VIDEO' | 'REEL', id: string, input: { status?: string; commentsEnabled?: boolean }) {
  return adminRequest<AdminFeedItem>(`/admin/feed-items/${type}/${id}`, {
    method: 'PATCH',
    body: JSON.stringify(input)
  });
}

export function deleteFeedItem(type: 'VIDEO' | 'REEL', id: string) {
  return adminRequest<AdminFeedItem>(`/feed/${type.toLowerCase()}/${id}`, {
    method: 'DELETE'
  });
}

export function getLiveRooms() {
  return adminRequest<AdminLiveRoom[]>('/admin/live-rooms');
}

export function getLiveRoomParticipants(roomId: string) {
  return adminRequest<LiveParticipant[]>(`/live/rooms/${roomId}/participants`);
}

export function getLiveRoomBlocks(roomId: string) {
  return adminRequest<LiveBlockedViewer[]>(`/live/rooms/${roomId}/blocks`);
}

export function blockLiveViewer(roomId: string, userId: string) {
  return adminRequest(`/live/rooms/${roomId}/blocks`, {
    method: 'POST',
    body: JSON.stringify({ userId })
  });
}

export function unblockLiveViewer(roomId: string, userId: string) {
  return adminRequest(`/live/rooms/${roomId}/blocks/${userId}`, {
    method: 'DELETE'
  });
}

export function getLocationInsights() {
  return adminRequest<LocationInsights>('/admin/location-insights');
}

export function getStorageSettings() {
  return adminRequest<StorageSettings>('/admin/storage-settings');
}

export function getStorageHealth() {
  return adminRequest<StorageHealth>('/admin/storage-health');
}

export function cleanupStorage(dryRun = true) {
  return adminRequest<StorageCleanupResult>('/admin/storage-cleanup', {
    method: 'POST',
    body: JSON.stringify({ dryRun })
  });
}

export function getMediaProcessingJobs() {
  return adminRequest<MediaProcessingJob[]>('/admin/media-processing-jobs');
}

export function getAuditLogs(filters: AuditLogFilters = {}) {
  const params = new URLSearchParams();

  if (filters.action) {
    params.set('action', filters.action);
  }

  if (filters.adminId) {
    params.set('adminId', filters.adminId);
  }

  if (filters.target) {
    params.set('target', filters.target);
  }

  const query = params.toString();
  return adminRequest<AdminAuditLog[]>(`/admin/audit-logs${query ? `?${query}` : ''}`);
}

export function updateStorageSettings(input: StorageSettingsInput) {
  return adminRequest<StorageSettings>('/admin/storage-settings', {
    method: 'PATCH',
    body: JSON.stringify(input)
  });
}

export function getSubscriptionPlans() {
  return adminRequest<SubscriptionPlan[]>('/admin/subscription-plans');
}

export function getPaymentEvents() {
  return adminRequest<PaymentEvent[]>('/admin/payment-events');
}

export function createSubscriptionPlan(input: PlanInput) {
  return adminRequest<SubscriptionPlan>('/admin/subscription-plans', {
    method: 'POST',
    body: JSON.stringify(input)
  });
}

export function updateSubscriptionPlan(id: string, input: Partial<PlanInput>) {
  return adminRequest<SubscriptionPlan>(`/admin/subscription-plans/${id}`, {
    method: 'PATCH',
    body: JSON.stringify(input)
  });
}

export function updateUserAccess(id: string, isActive: boolean) {
  return adminRequest<AdminUser>(`/admin/users/${id}/access`, {
    method: 'PATCH',
    body: JSON.stringify({ isActive })
  });
}

export function cancelUserSubscription(id: string) {
  return adminRequest<AdminUser>(`/admin/users/${id}/subscription`, {
    method: 'DELETE'
  });
}

export function deleteUser(id: string) {
  return adminRequest<{ deleted: boolean; id: string }>(`/admin/users/${id}`, {
    method: 'DELETE'
  });
}

async function adminRequest<T>(path: string, init?: RequestInit) {
  const response = await fetch(`${API_URL}${path}`, {
    ...init,
    headers: {
      ...authHeaders(),
      ...(init?.body ? { 'Content-Type': 'application/json' } : {}),
      ...init?.headers
    }
  });

  if (!response.ok) {
    const data = await response.json().catch(() => null);
    throw new Error(data?.message ?? 'Unable to load admin data');
  }

  return response.json() as Promise<T>;
}

function authHeaders(): HeadersInit {
  const token = localStorage.getItem('nimbark_admin_token');

  return token
    ? {
        Authorization: `Bearer ${token}`
      }
    : {};
}

async function authRequest(path: string, body: unknown) {
  const response = await fetch(`${API_URL}${path}`, {
    method: 'POST',
    headers: {
      'Content-Type': 'application/json'
    },
    body: JSON.stringify(body)
  });

  const data = await response.json();

  if (!response.ok) {
    throw new Error(data.message ?? 'Authentication failed');
  }

  return data as AuthResponse;
}
