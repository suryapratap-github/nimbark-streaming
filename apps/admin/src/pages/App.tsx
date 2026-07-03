import {
  Activity,
  Ban,
  Cpu,
  CreditCard,
  Database,
  Eye,
  EyeOff,
  Flag,
  History,
  LogOut,
  Monitor,
  Moon,
  Pencil,
  PlaySquare,
  Plus,
  Radio,
  Sun,
  Users
} from 'lucide-react';
import { FormEvent, useEffect, useState } from 'react';
import { MetricCard } from '../components/MetricCard';
import {
  AdminLiveRoom,
  AdminFeedItem,
  AdminAuditLog,
  AdminReport,
  AdminUser,
  AuthResponse,
  AuthUser,
  CreateUserInput,
  FeedStatusFilter,
  ReportAction,
  ReportStatusFilter,
  LiveBlockedViewer,
  LocationInsights,
  LiveParticipant,
  MediaProcessingJob,
  PaymentEvent,
  PlanInput,
  StorageCleanupResult,
  StorageHealth,
  StorageSettings,
  StorageSettingsInput,
  SubscriptionPlan,
  UpdateUserInput,
  actionReport,
  blockLiveViewer,
  cancelUserSubscription,
  cleanupStorage,
  createUser,
  createSubscriptionPlan,
  deleteFeedItem,
  deleteUser,
  getAuditLogs,
  getDashboard,
  getFeedItems,
  getLiveRoomBlocks,
  getLiveRooms,
  getLiveRoomParticipants,
  getLocationInsights,
  getMediaProcessingJobs,
  getPaymentEvents,
  getReports,
  getSubscriptionPlans,
  getStorageSettings,
  getStorageHealth,
  getUsers,
  loginAdmin,
  updateFeedItem,
  updateSubscriptionPlan,
  updateReportStatus,
  updateStorageSettings,
  updateUser,
  updateUserAccess,
  unblockLiveViewer
} from '../lib/api';

type Dashboard = Awaited<ReturnType<typeof getDashboard>>;
type AdminView = 'dashboard' | 'users' | 'plans' | 'payments' | 'storage' | 'processing' | 'feed' | 'reports' | 'audit' | 'live';
type ThemePreference = 'system' | 'light' | 'dark';

const themeStorageKey = 'nimbark_admin_theme';

export function App() {
  const [dashboard, setDashboard] = useState<Dashboard | null>(null);
  const [users, setUsers] = useState<AdminUser[]>([]);
  const [reports, setReports] = useState<AdminReport[]>([]);
  const [reportStatusFilter, setReportStatusFilter] = useState<ReportStatusFilter>('OPEN');
  const [feedItems, setFeedItems] = useState<AdminFeedItem[]>([]);
  const [feedStatusFilter, setFeedStatusFilter] = useState<FeedStatusFilter>('ACTIVE');
  const [liveRooms, setLiveRooms] = useState<AdminLiveRoom[]>([]);
  const [plans, setPlans] = useState<SubscriptionPlan[]>([]);
  const [paymentEvents, setPaymentEvents] = useState<PaymentEvent[]>([]);
  const [processingJobs, setProcessingJobs] = useState<MediaProcessingJob[]>([]);
  const [auditLogs, setAuditLogs] = useState<AdminAuditLog[]>([]);
  const [auditActionFilter, setAuditActionFilter] = useState('');
  const [auditTargetFilter, setAuditTargetFilter] = useState('');
  const [storageSettings, setStorageSettings] = useState<StorageSettings | null>(null);
  const [storageHealth, setStorageHealth] = useState<StorageHealth | null>(null);
  const [storageCleanupResult, setStorageCleanupResult] = useState<StorageCleanupResult | null>(null);
  const [locationInsights, setLocationInsights] = useState<LocationInsights | null>(null);
  const [activeView, setActiveView] = useState<AdminView>('dashboard');
  const [dataError, setDataError] = useState('');
  const [editingUser, setEditingUser] = useState<AdminUser | null>(null);
  const [isCreatingUser, setIsCreatingUser] = useState(false);
  const [authUser, setAuthUser] = useState<AuthUser | null>(() => {
    const saved = localStorage.getItem('nimbark_admin_user');
    return saved ? (JSON.parse(saved) as AuthUser) : null;
  });
  const [authError, setAuthError] = useState('');
  const [isSubmitting, setIsSubmitting] = useState(false);
  const [themePreference, setThemePreference] = useState<ThemePreference>(() => {
    const savedTheme = localStorage.getItem(themeStorageKey);
    return savedTheme === 'light' || savedTheme === 'dark' || savedTheme === 'system' ? savedTheme : 'system';
  });

  useEffect(() => {
    const mediaQuery = window.matchMedia('(prefers-color-scheme: dark)');

    function applyTheme() {
      const resolvedTheme = themePreference === 'system' ? (mediaQuery.matches ? 'dark' : 'light') : themePreference;
      document.documentElement.dataset.theme = resolvedTheme;
      document.documentElement.dataset.themePreference = themePreference;
      document.documentElement.style.colorScheme = resolvedTheme;
    }

    applyTheme();
    localStorage.setItem(themeStorageKey, themePreference);
    mediaQuery.addEventListener('change', applyTheme);

    return () => mediaQuery.removeEventListener('change', applyTheme);
  }, [themePreference]);

  useEffect(() => {
    if (!authUser) {
      return;
    }

    setDataError('');

    if (activeView === 'dashboard') {
      getDashboard().then(setDashboard).catch(handleDataError);
      getLocationInsights().then(setLocationInsights).catch(handleDataError);
    }

    if (activeView === 'users') {
      getUsers().then(setUsers).catch(handleDataError);
    }

    if (activeView === 'plans') {
      getSubscriptionPlans().then(setPlans).catch(handleDataError);
    }

    if (activeView === 'payments') {
      getPaymentEvents().then(setPaymentEvents).catch(handleDataError);
    }

    if (activeView === 'storage') {
      getStorageSettings().then(setStorageSettings).catch(handleDataError);
      getStorageHealth().then(setStorageHealth).catch(handleDataError);
    }

    if (activeView === 'processing') {
      getMediaProcessingJobs().then(setProcessingJobs).catch(handleDataError);
    }

    if (activeView === 'audit') {
      getAuditLogs({
        action: auditActionFilter || undefined,
        target: auditTargetFilter || undefined
      })
        .then(setAuditLogs)
        .catch(handleDataError);
    }

    if (activeView === 'reports') {
      getReports(reportStatusFilter).then(setReports).catch(handleDataError);
    }

    if (activeView === 'feed') {
      getFeedItems(feedStatusFilter).then(setFeedItems).catch(handleDataError);
    }

    if (activeView === 'live') {
      getLiveRooms().then(setLiveRooms).catch(handleDataError);
    }
  }, [activeView, authUser, feedStatusFilter, reportStatusFilter, auditActionFilter, auditTargetFilter]);

  async function handleAuthSubmit(event: FormEvent<HTMLFormElement>) {
    event.preventDefault();
    setAuthError('');
    setIsSubmitting(true);

    const formData = new FormData(event.currentTarget);
    const email = String(formData.get('email') ?? '');
    const password = String(formData.get('password') ?? '');

    try {
      const response = await loginAdmin({ email, password });
      saveAuth(response);
    } catch (error) {
      setAuthError(error instanceof Error ? error.message : 'Authentication failed');
    } finally {
      setIsSubmitting(false);
    }
  }

  function saveAuth(response: AuthResponse) {
    localStorage.setItem('nimbark_admin_token', response.accessToken);
    localStorage.setItem('nimbark_admin_user', JSON.stringify(response.user));
    setAuthUser(response.user);
  }

  function logout() {
    const confirmed = window.confirm('Log out of the admin panel?');

    if (!confirmed) {
      return;
    }

    localStorage.removeItem('nimbark_admin_token');
    localStorage.removeItem('nimbark_admin_user');
    setAuthUser(null);
  }

  function handleDataError(error: unknown) {
    setDataError(error instanceof Error ? error.message : 'Unable to load admin data');
  }

  function renderContent() {
    if (dataError) {
      return <section className="panel empty-state">{dataError}</section>;
    }

    if (activeView === 'users') {
      return (
        <UsersView
          currentUserId={authUser?.id}
          editingUser={editingUser}
          isCreatingUser={isCreatingUser}
          users={users}
          onCancelForm={() => {
            setEditingUser(null);
            setIsCreatingUser(false);
          }}
          onCreateClick={() => {
            setEditingUser(null);
            setIsCreatingUser(true);
          }}
          onDeleteUser={handleDeleteUser}
          onEditUser={(user) => {
            setIsCreatingUser(false);
            setEditingUser(user);
          }}
          onSubmitUser={handleSubmitUser}
          onCancelSubscription={handleCancelSubscription}
          onToggleAccess={handleToggleAccess}
        />
      );
    }

    if (activeView === 'reports') {
      return (
        <ReportsView
          reports={reports}
          statusFilter={reportStatusFilter}
          onStatusFilterChange={setReportStatusFilter}
          onReportAction={handleReportAction}
          onUpdateReportStatus={handleUpdateReportStatus}
        />
      );
    }

    if (activeView === 'feed') {
      return (
        <FeedManagementView
          feedItems={feedItems}
          statusFilter={feedStatusFilter}
          onDeleteFeedItem={handleDeleteFeedItem}
          onStatusFilterChange={setFeedStatusFilter}
          onUpdateFeedItem={handleUpdateFeedItem}
        />
      );
    }

    if (activeView === 'plans') {
      return <PlansView plans={plans} onSavePlan={handleSavePlan} />;
    }

    if (activeView === 'payments') {
      return <PaymentsView events={paymentEvents} />;
    }

    if (activeView === 'storage') {
      return (
        <StorageView
          cleanupResult={storageCleanupResult}
          health={storageHealth}
          settings={storageSettings}
          onCleanup={handleStorageCleanup}
          onSave={handleSaveStorageSettings}
        />
      );
    }

    if (activeView === 'processing') {
      return <ProcessingView jobs={processingJobs} />;
    }

    if (activeView === 'audit') {
      return (
        <AuditLogsView
          actionFilter={auditActionFilter}
          logs={auditLogs}
          targetFilter={auditTargetFilter}
          onActionFilterChange={setAuditActionFilter}
          onTargetFilterChange={setAuditTargetFilter}
        />
      );
    }

    if (activeView === 'live') {
      return <LiveView liveRooms={liveRooms} />;
    }

    return <DashboardView dashboard={dashboard} locationInsights={locationInsights} />;
  }

  async function handleSavePlan(input: PlanInput, planId?: string) {
    setDataError('');

    try {
      const savedPlan = planId
        ? await updateSubscriptionPlan(planId, input)
        : await createSubscriptionPlan(input);
      setPlans((currentPlans) => {
        const exists = currentPlans.some((plan) => plan.id === savedPlan.id);
        return exists
          ? currentPlans.map((plan) => (plan.id === savedPlan.id ? savedPlan : plan))
          : [savedPlan, ...currentPlans];
      });
    } catch (error) {
      handleDataError(error);
    }
  }

  async function handleSaveStorageSettings(input: StorageSettingsInput) {
    setDataError('');

    try {
      const savedSettings = await updateStorageSettings(input);
      setStorageSettings(savedSettings);
      getStorageHealth().then(setStorageHealth).catch(handleDataError);
    } catch (error) {
      handleDataError(error);
    }
  }

  async function handleStorageCleanup(dryRun: boolean) {
    setDataError('');

    if (!dryRun) {
      const confirmed = window.confirm('Delete orphaned local files? This cannot be undone.');

      if (!confirmed) {
        return;
      }
    }

    try {
      const result = await cleanupStorage(dryRun);
      setStorageCleanupResult(result);
    } catch (error) {
      handleDataError(error);
    }
  }

  async function handleUpdateReportStatus(report: AdminReport, status: string) {
    setDataError('');

    try {
      const updatedReport = await updateReportStatus(report.id, status);
      setReports((currentReports) =>
        currentReports.map((currentReport) => (currentReport.id === updatedReport.id ? updatedReport : currentReport))
      );
      setDashboard(null);
    } catch (error) {
      handleDataError(error);
    }
  }

  async function handleReportAction(report: AdminReport, action: ReportAction) {
    setDataError('');

    if (action === 'BLOCK_USER') {
      const username = report.subjectUser ? `@${report.subjectUser.username}` : 'this user';
      const confirmed = window.confirm(`Block ${username} from the platform?`);

      if (!confirmed) {
        return;
      }
    }

    if (action === 'BLOCK_CONTENT') {
      const confirmed = window.confirm(`Block or remove reported ${report.targetType.toLowerCase()}?`);

      if (!confirmed) {
        return;
      }
    }

    try {
      const updatedReport = await actionReport(report.id, action);
      setReports((currentReports) =>
        currentReports.map((currentReport) => (currentReport.id === updatedReport.id ? updatedReport : currentReport))
      );
      setDashboard(null);
    } catch (error) {
      handleDataError(error);
    }
  }

  async function handleUpdateFeedItem(item: AdminFeedItem, input: { status?: string; commentsEnabled?: boolean }) {
    setDataError('');

    if (input.status && input.status !== item.status) {
      const label = item.label || item.feedType.toLowerCase();
      const action = input.status === 'PUBLISHED' ? 'restore' : 'block';
      const confirmed = window.confirm(`${action === 'restore' ? 'Restore' : 'Block'} ${label}?`);

      if (!confirmed) {
        return;
      }
    }

    try {
      const updatedItem = await updateFeedItem(item.feedType, item.id, input);
      const normalizedItem = { ...updatedItem, feedType: item.feedType, label: item.feedType === 'VIDEO' ? updatedItem.title ?? item.label : updatedItem.caption ?? item.label };
      setFeedItems((currentItems) =>
        currentItems.map((currentItem) => (currentItem.id === item.id && currentItem.feedType === item.feedType ? normalizedItem : currentItem))
      );
    } catch (error) {
      handleDataError(error);
    }
  }

  async function handleDeleteFeedItem(item: AdminFeedItem) {
    setDataError('');

    const confirmed = window.confirm(`Delete ${item.label || item.feedType.toLowerCase()}?`);

    if (!confirmed) {
      return;
    }

    try {
      await deleteFeedItem(item.feedType, item.id);
      setFeedItems((currentItems) =>
        currentItems.filter((currentItem) => !(currentItem.id === item.id && currentItem.feedType === item.feedType))
      );
      setDashboard(null);
    } catch (error) {
      handleDataError(error);
    }
  }

  async function handleSubmitUser(input: CreateUserInput | UpdateUserInput) {
    setDataError('');

    try {
      const savedUser = editingUser
        ? await updateUser(editingUser.id, input as UpdateUserInput)
        : await createUser(input as CreateUserInput);

      setUsers((currentUsers) => {
        const exists = currentUsers.some((user) => user.id === savedUser.id);
        return exists
          ? currentUsers.map((user) => (user.id === savedUser.id ? savedUser : user))
          : [savedUser, ...currentUsers];
      });
      setEditingUser(null);
      setIsCreatingUser(false);
      setDashboard(null);
    } catch (error) {
      handleDataError(error);
    }
  }

  async function handleToggleAccess(user: AdminUser) {
    setDataError('');

    const action = user.isActive ? 'Block' : 'Unblock';
    const confirmed = window.confirm(`${action} ${user.displayName}?`);

    if (!confirmed) {
      return;
    }

    try {
      const updatedUser = await updateUserAccess(user.id, !user.isActive);
      setUsers((currentUsers) =>
        currentUsers.map((currentUser) => (currentUser.id === updatedUser.id ? updatedUser : currentUser))
      );
    } catch (error) {
      handleDataError(error);
    }
  }

  async function handleCancelSubscription(user: AdminUser) {
    setDataError('');

    const confirmed = window.confirm(
      `Revoke ${user.displayName}'s local creator access? Billing cancellation must happen in RevenueCat or the app store.`
    );

    if (!confirmed) {
      return;
    }

    try {
      const updatedUser = await cancelUserSubscription(user.id);
      setUsers((currentUsers) =>
        currentUsers.map((currentUser) => (currentUser.id === updatedUser.id ? updatedUser : currentUser))
      );
    } catch (error) {
      handleDataError(error);
    }
  }

  async function handleDeleteUser(user: AdminUser) {
    setDataError('');

    const confirmed = window.confirm(`Delete ${user.displayName}? This cannot be undone.`);

    if (!confirmed) {
      return;
    }

    try {
      await deleteUser(user.id);
      setUsers((currentUsers) => currentUsers.filter((currentUser) => currentUser.id !== user.id));
      setDashboard(null);
    } catch (error) {
      handleDataError(error);
    }
  }

  if (!authUser) {
    return (
      <main className="auth-page">
        <section className="auth-panel">
          <div>
            <p>Admin Access</p>
            <h1>Nimbark Admin</h1>
          </div>

          <form className="auth-form" onSubmit={handleAuthSubmit}>
            <label>
              Email
              <input name="email" type="email" autoComplete="email" required />
            </label>
            <label>
              Password
              <PasswordInput name="password" autoComplete="current-password" required minLength={8} />
            </label>

            {authError && <p className="form-error">{authError}</p>}

            <button className="primary-action" type="submit" disabled={isSubmitting}>
              {isSubmitting ? 'Please wait' : 'Login'}
            </button>
          </form>
        </section>
      </main>
    );
  }

  return (
    <main className="admin-shell">
      <aside className="sidebar">
        <h1>Nimbark Admin</h1>
        <div className="admin-user">
          <strong>{authUser.displayName}</strong>
          <span>{authUser.role}</span>
        </div>
        <ThemeSwitcher value={themePreference} onChange={setThemePreference} />
        <nav>
          <button className={activeView === 'dashboard' ? 'active' : ''} type="button" onClick={() => setActiveView('dashboard')}>
            <Activity size={18} /> Dashboard
          </button>
          <button className={activeView === 'users' ? 'active' : ''} type="button" onClick={() => setActiveView('users')}>
            <Users size={18} /> Users
          </button>
          <button className={activeView === 'plans' ? 'active' : ''} type="button" onClick={() => setActiveView('plans')}>
            <CreditCard size={18} /> Plans
          </button>
          <button className={activeView === 'payments' ? 'active' : ''} type="button" onClick={() => setActiveView('payments')}>
            <CreditCard size={18} /> Payments
          </button>
          <button className={activeView === 'storage' ? 'active' : ''} type="button" onClick={() => setActiveView('storage')}>
            <Database size={18} /> Storage
          </button>
          <button className={activeView === 'processing' ? 'active' : ''} type="button" onClick={() => setActiveView('processing')}>
            <Cpu size={18} /> Processing
          </button>
          <button className={activeView === 'feed' ? 'active' : ''} type="button" onClick={() => setActiveView('feed')}>
            <PlaySquare size={18} /> Feed
          </button>
          <button className={activeView === 'reports' ? 'active' : ''} type="button" onClick={() => setActiveView('reports')}>
            <Flag size={18} /> Reports
          </button>
          <button className={activeView === 'audit' ? 'active' : ''} type="button" onClick={() => setActiveView('audit')}>
            <History size={18} /> Audit
          </button>
          <button className={activeView === 'live' ? 'active' : ''} type="button" onClick={() => setActiveView('live')}>
            <Radio size={18} /> Live
          </button>
        </nav>
        <button className="logout-button" type="button" onClick={logout}>
          <LogOut size={18} /> Logout
        </button>
      </aside>

      <section className="content">
        <header>
          <p>Operations</p>
          <h2>{viewTitle(activeView)}</h2>
        </header>
        {renderContent()}
      </section>
    </main>
  );
}

function ThemeSwitcher({
  value,
  onChange
}: {
  value: ThemePreference;
  onChange: (value: ThemePreference) => void;
}) {
  const options: Array<{ value: ThemePreference; label: string; icon: typeof Sun }> = [
    { value: 'light', label: 'Light', icon: Sun },
    { value: 'dark', label: 'Dark', icon: Moon },
    { value: 'system', label: 'System', icon: Monitor }
  ];

  return (
    <div className="theme-switcher" aria-label="Theme mode">
      {options.map((option) => {
        const Icon = option.icon;
        return (
          <button
            aria-pressed={value === option.value}
            className={value === option.value ? 'active-theme' : ''}
            key={option.value}
            type="button"
            title={`${option.label} theme`}
            onClick={() => onChange(option.value)}
          >
            <Icon size={16} />
            <span>{option.label}</span>
          </button>
        );
      })}
    </div>
  );
}

function PasswordInput({
  autoComplete,
  minLength,
  name,
  required
}: {
  autoComplete?: string;
  minLength?: number;
  name: string;
  required?: boolean;
}) {
  const [isVisible, setIsVisible] = useState(false);

  return (
    <span className="password-input">
      <input
        name={name}
        type={isVisible ? 'text' : 'password'}
        autoComplete={autoComplete}
        required={required}
        minLength={minLength}
      />
      <button
        aria-label={isVisible ? 'Hide password' : 'Show password'}
        type="button"
        onClick={() => setIsVisible((current) => !current)}
      >
        {isVisible ? <EyeOff size={16} /> : <Eye size={16} />}
      </button>
    </span>
  );
}

function DashboardView({
  dashboard,
  locationInsights
}: {
  dashboard: Dashboard | null;
  locationInsights: LocationInsights | null;
}) {
  return (
    <>
      <div className="metrics">
        <MetricCard label="Users" value={dashboard?.users ?? '-'} />
        <MetricCard label="Videos" value={dashboard?.videos ?? '-'} />
        <MetricCard label="Reels" value={dashboard?.reels ?? '-'} />
        <MetricCard label="Pending Reports" value={dashboard?.pendingReports ?? '-'} />
        <MetricCard label="Active Live Rooms" value={dashboard?.activeLiveRooms ?? '-'} />
      </div>

      <section className="panel">
        <h3>Moderation Snapshot</h3>
        <div className="summary-list">
          <span>Open reports: {dashboard?.pendingReports ?? '-'}</span>
          <span>Live now: {dashboard?.activeLiveRooms ?? '-'}</span>
        </div>
      </section>

      <section className="panel table-panel location-panel">
        <div className="panel-heading">
          <h3>Location Insights</h3>
          <span>{locationInsights?.locatedUsers ?? 0} users located</span>
        </div>
        {locationInsights?.topLocations.length ? (
          <table>
            <thead>
              <tr>
                <th>Approx. Coordinates</th>
                <th>Users</th>
                <th>Pings</th>
                <th>Last Seen</th>
              </tr>
            </thead>
            <tbody>
              {locationInsights.topLocations.map((location) => (
                <tr key={`${location.latitude}-${location.longitude}`}>
                  <td>
                    <strong>{location.latitude}, {location.longitude}</strong>
                    <span>Rounded location cluster</span>
                  </td>
                  <td>{location.users}</td>
                  <td>{location.pings}</td>
                  <td>{formatDate(location.lastSeenAt)}</td>
                </tr>
              ))}
            </tbody>
          </table>
        ) : (
          <div className="empty-state inline-empty">No location pings captured yet.</div>
        )}
      </section>
    </>
  );
}

function UsersView({
  currentUserId,
  editingUser,
  isCreatingUser,
  users,
  onCancelForm,
  onCreateClick,
  onDeleteUser,
  onEditUser,
  onSubmitUser,
  onCancelSubscription,
  onToggleAccess
}: {
  currentUserId?: string;
  editingUser: AdminUser | null;
  isCreatingUser: boolean;
  users: AdminUser[];
  onCancelForm: () => void;
  onCreateClick: () => void;
  onDeleteUser: (user: AdminUser) => void;
  onEditUser: (user: AdminUser) => void;
  onSubmitUser: (input: CreateUserInput | UpdateUserInput) => void;
  onCancelSubscription: (user: AdminUser) => void;
  onToggleAccess: (user: AdminUser) => void;
}) {
  if (!users.length) {
    return (
      <>
        <UserToolbar onCreateClick={onCreateClick} />
        {(isCreatingUser || editingUser) && (
          <UserForm editingUser={editingUser} onCancel={onCancelForm} onSubmit={onSubmitUser} />
        )}
        <section className="panel empty-state">No users found.</section>
      </>
    );
  }

  return (
    <>
      <UserToolbar onCreateClick={onCreateClick} />
      {(isCreatingUser || editingUser) && (
        <UserForm editingUser={editingUser} onCancel={onCancelForm} onSubmit={onSubmitUser} />
      )}
      <section className="panel table-panel">
        <table>
          <thead>
            <tr>
              <th>User</th>
              <th>Role</th>
              <th>Status</th>
              <th>Location</th>
              <th>Videos</th>
              <th>Subscription</th>
              <th>Joined</th>
              <th>Actions</th>
            </tr>
          </thead>
          <tbody>
            {users.map((user) => (
              <tr key={user.id}>
                <td>
                  <div className="user-cell">
                    <UserAvatar user={user} />
                    <div>
                      <strong>{user.displayName}</strong>
                      <span>@{user.username} · {user.email}</span>
                    </div>
                  </div>
                </td>
                <td>{user.role}</td>
                <td>{user.isActive ? 'Active' : 'Disabled'}</td>
                <td>
                  {user.lastLatitude != null && user.lastLongitude != null ? (
                    <>
                      <strong>{user.lastLatitude.toFixed(3)}, {user.lastLongitude.toFixed(3)}</strong>
                      <span>{user.locationSource ?? 'captured'} · {user.locationUpdatedAt ? formatDate(user.locationUpdatedAt) : '-'}</span>
                    </>
                  ) : (
                    <span className="muted-text">Not captured</span>
                  )}
                </td>
                <td>{user._count.videos + user._count.reels}</td>
                <td>
                  {user.subscriptions[0] ? (
                    <>
                      <strong>{user.subscriptions[0].plan.name}</strong>
                      <span>Expires {formatDate(user.subscriptions[0].expiresAt)}</span>
                      <span>{user.subscriptions[0].externalProductId ?? 'No RevenueCat product'}</span>
                      <span>{user.subscriptions[0].externalSubscriptionId ?? 'No transaction id'}</span>
                      <span>
                        Last event{' '}
                        {user.subscriptions[0].latestEventAt
                          ? formatDate(user.subscriptions[0].latestEventAt)
                          : '-'}
                      </span>
                    </>
                  ) : (
                    <span className="muted-text">No active plan</span>
                  )}
                </td>
                <td>{formatDate(user.createdAt)}</td>
                <td>
                  {user.role === 'ADMIN' ? (
                    <span className="muted-text">Protected</span>
                  ) : (
                    <div className="row-actions">
                      <button className="icon-action" type="button" onClick={() => onEditUser(user)} title="Edit user">
                        <Pencil size={16} />
                      </button>
                      <button
                        className={user.isActive ? 'secondary-action' : 'success-action'}
                        type="button"
                        disabled={user.id === currentUserId}
                        onClick={() => onToggleAccess(user)}
                      >
                        {user.isActive ? 'Block' : 'Unblock'}
                      </button>
                      {user.subscriptions[0] && (
                        <button
                          className="danger-action"
                          type="button"
                          disabled={user.id === currentUserId}
                          onClick={() => onCancelSubscription(user)}
                        >
                          Revoke access
                        </button>
                      )}
                      <button
                        className="danger-action"
                        type="button"
                        disabled={user.id === currentUserId}
                        onClick={() => onDeleteUser(user)}
                      >
                        Delete
                      </button>
                    </div>
                  )}
                </td>
              </tr>
            ))}
          </tbody>
        </table>
      </section>
    </>
  );
}

function UserToolbar({ onCreateClick }: { onCreateClick: () => void }) {
  return (
    <div className="toolbar">
      <button className="primary-action compact-action" type="button" onClick={onCreateClick}>
        <Plus size={16} /> Create user
      </button>
    </div>
  );
}

function UserAvatar({ user }: { user: AdminUser }) {
  const initial = (user.displayName || user.username || user.email || '?').trim().charAt(0).toUpperCase();

  if (user.avatarUrl) {
    return <img className="user-avatar" src={user.avatarUrl} alt="" />;
  }

  return (
    <span className="user-avatar user-avatar-initial" aria-hidden="true">
      {initial}
    </span>
  );
}

function UserForm({
  editingUser,
  onCancel,
  onSubmit
}: {
  editingUser: AdminUser | null;
  onCancel: () => void;
  onSubmit: (input: CreateUserInput | UpdateUserInput) => void;
}) {
  function handleSubmit(event: FormEvent<HTMLFormElement>) {
    event.preventDefault();
    const formData = new FormData(event.currentTarget);
    const password = String(formData.get('password') ?? '');
    const baseInput = {
      email: String(formData.get('email') ?? ''),
      displayName: String(formData.get('displayName') ?? ''),
      username: String(formData.get('username') ?? ''),
      role: String(formData.get('role') ?? 'USER') as 'USER' | 'CREATOR',
      ...(password ? { password } : {})
    };
    const input = editingUser ? { ...baseInput, bio: String(formData.get('bio') ?? '') } : baseInput;

    onSubmit(input);
  }

  return (
    <section className="panel user-form-panel">
      <h3>{editingUser ? 'Edit User' : 'Create User'}</h3>
      <form className="user-form" onSubmit={handleSubmit}>
        <label>
          Display name
          <input name="displayName" defaultValue={editingUser?.displayName} required />
        </label>
        <label>
          Username
          <input name="username" defaultValue={editingUser?.username} required />
        </label>
        <label>
          Email
          <input name="email" type="email" defaultValue={editingUser?.email} required />
        </label>
        <label>
          Role
          <select name="role" defaultValue={editingUser?.role === 'CREATOR' ? 'CREATOR' : 'USER'}>
            <option value="USER">User</option>
            <option value="CREATOR">Creator</option>
          </select>
        </label>
        <label>
          Password
          <PasswordInput name="password" required={!editingUser} minLength={8} />
        </label>
        <label className="wide-field">
          Bio
          <textarea name="bio" defaultValue={editingUser?.bio ?? ''} rows={3} />
        </label>
        <div className="form-actions">
          <button className="primary-action compact-action" type="submit">
            {editingUser ? 'Save changes' : 'Create user'}
          </button>
          <button className="secondary-action" type="button" onClick={onCancel}>
            Cancel
          </button>
        </div>
      </form>
    </section>
  );
}

function ReportsView({
  reports,
  statusFilter,
  onStatusFilterChange,
  onReportAction,
  onUpdateReportStatus
}: {
  reports: AdminReport[];
  statusFilter: ReportStatusFilter;
  onStatusFilterChange: (status: ReportStatusFilter) => void;
  onReportAction: (report: AdminReport, action: ReportAction) => void;
  onUpdateReportStatus: (report: AdminReport, status: string) => void;
}) {
  const filters: Array<{ label: string; value: ReportStatusFilter }> = [
    { label: 'Pending', value: 'OPEN' },
    { label: 'Reviewing', value: 'REVIEWING' },
    { label: 'Actioned', value: 'RESOLVED' },
    { label: 'Dismissed', value: 'REJECTED' },
    { label: 'All', value: 'ALL' }
  ];

  if (!reports.length) {
    return (
      <>
        <div className="filter-bar">
          {filters.map((filter) => (
            <button
              className={statusFilter === filter.value ? 'active-filter' : ''}
              key={filter.value}
              type="button"
              onClick={() => onStatusFilterChange(filter.value)}
            >
              {filter.label}
            </button>
          ))}
        </div>
        <section className="panel empty-state">No reports for this filter.</section>
      </>
    );
  }

  return (
    <>
      <div className="filter-bar">
        {filters.map((filter) => (
          <button
            className={statusFilter === filter.value ? 'active-filter' : ''}
            key={filter.value}
            type="button"
            onClick={() => onStatusFilterChange(filter.value)}
          >
            {filter.label}
          </button>
        ))}
      </div>
      <section className="panel table-panel">
        <table>
          <thead>
            <tr>
              <th>Reason</th>
              <th>Target</th>
              <th>Reporter</th>
              <th>Subject</th>
              <th>Status</th>
              <th>Created</th>
              <th>Actions</th>
            </tr>
          </thead>
          <tbody>
            {reports.map((report) => {
              const canBlockContent = ['VIDEO', 'REEL', 'COMMENT', 'LIVE_ROOM'].includes(report.targetType);
              const targetUrl = mediaUrl(report.targetUrl);
              return (
                <tr key={report.id}>
                  <td>{report.reason}</td>
                  <td>
                    <strong>{report.targetType}</strong>
                    <span>{report.targetLabel}</span>
                    <span>{report.targetId}</span>
                    {targetUrl && (
                      <a className="inline-link" href={targetUrl} target="_blank" rel="noreferrer">
                        Open
                      </a>
                    )}
                  </td>
                  <td>
                    <strong>{report.reporter.displayName}</strong>
                    <span>@{report.reporter.username}</span>
                  </td>
                  <td>
                    {report.subjectUser ? (
                      <>
                        <strong>{report.subjectUser.displayName}</strong>
                        <span>@{report.subjectUser.username}</span>
                      </>
                    ) : (
                      <span className="muted-text">No subject</span>
                    )}
                  </td>
                  <td>{report.status}</td>
                  <td>{formatDate(report.createdAt)}</td>
                  <td>
                    <div className="row-actions">
                      <button
                        className="secondary-action compact-action"
                        type="button"
                        disabled={report.status === 'REVIEWING'}
                        onClick={() => onReportAction(report, 'MARK_REVIEWING')}
                      >
                        Review
                      </button>
                      {canBlockContent && (
                        <button
                          className="danger-action compact-action"
                          type="button"
                          disabled={report.status === 'RESOLVED'}
                          onClick={() => onReportAction(report, 'BLOCK_CONTENT')}
                        >
                          Block content
                        </button>
                      )}
                      {report.subjectUser && (
                        <button
                          className="danger-action compact-action"
                          type="button"
                          disabled={report.status === 'RESOLVED'}
                          onClick={() => onReportAction(report, 'BLOCK_USER')}
                        >
                          Block user
                        </button>
                      )}
                      <button
                        className="success-action compact-action"
                        type="button"
                        disabled={report.status === 'RESOLVED'}
                        onClick={() => onUpdateReportStatus(report, 'RESOLVED')}
                      >
                        Resolve
                      </button>
                      <button
                        className="secondary-action compact-action"
                        type="button"
                        disabled={report.status === 'REJECTED'}
                        onClick={() => onReportAction(report, 'DISMISS')}
                      >
                        Dismiss
                      </button>
                    </div>
                  </td>
                </tr>
              );
            })}
          </tbody>
        </table>
      </section>
    </>
  );
}

function FeedManagementView({
  feedItems,
  onDeleteFeedItem,
  onStatusFilterChange,
  statusFilter,
  onUpdateFeedItem
}: {
  feedItems: AdminFeedItem[];
  onDeleteFeedItem: (item: AdminFeedItem) => void;
  onStatusFilterChange: (status: FeedStatusFilter) => void;
  statusFilter: FeedStatusFilter;
  onUpdateFeedItem: (item: AdminFeedItem, input: { status?: string; commentsEnabled?: boolean }) => void;
}) {
  const filters: Array<{ label: string; value: FeedStatusFilter }> = [
    { label: 'Active', value: 'ACTIVE' },
    { label: 'Published', value: 'PUBLISHED' },
    { label: 'Blocked', value: 'BLOCKED' },
    { label: 'Deleted', value: 'DELETED' }
  ];

  if (!feedItems.length) {
    return (
      <>
        <div className="filter-bar">
          {filters.map((filter) => (
            <button
              className={statusFilter === filter.value ? 'active-filter' : ''}
              key={filter.value}
              type="button"
              onClick={() => onStatusFilterChange(filter.value)}
            >
              {filter.label}
            </button>
          ))}
        </div>
        <section className="panel empty-state">No feed posts found for this filter.</section>
      </>
    );
  }

  return (
    <>
      <div className="filter-bar">
        {filters.map((filter) => (
          <button
            className={statusFilter === filter.value ? 'active-filter' : ''}
            key={filter.value}
            type="button"
            onClick={() => onStatusFilterChange(filter.value)}
          >
            {filter.label}
          </button>
        ))}
      </div>
      <section className="panel table-panel">
        <table>
          <thead>
            <tr>
              <th>Post</th>
              <th>Creator</th>
              <th>Stats</th>
              <th>Comments</th>
              <th>Status</th>
              <th>Created</th>
              <th>Actions</th>
            </tr>
          </thead>
          <tbody>
            {feedItems.map((item) => {
              const isBlocked = item.status !== 'PUBLISHED';
              const isDeleted = item.status === 'DELETED';
              const previewUrl = mediaUrl(item.mediaAsset.publicUrl);
              const thumbnailUrl = mediaUrl(item.thumbnail?.publicUrl ?? null);
              return (
                <tr key={`${item.feedType}-${item.id}`}>
                  <td>
                    <div className="feed-post-cell">
                      {thumbnailUrl ? (
                        <img src={thumbnailUrl} alt="" />
                      ) : (
                        <div className="feed-post-thumb-placeholder">
                          <PlaySquare size={18} />
                        </div>
                      )}
                      <div>
                        <strong>{item.label || (item.feedType === 'VIDEO' ? 'Untitled video' : 'Reel')}</strong>
                        <span>
                          {item.feedType} {item.mediaAsset.durationMs ? `• ${formatMediaDuration(item.mediaAsset.durationMs)}` : ''}
                        </span>
                      </div>
                    </div>
                  </td>
                  <td>
                    <strong>{item.creator.displayName}</strong>
                    <span>@{item.creator.username}</span>
                  </td>
                  <td>
                    <span>{item.viewCount} views</span>
                    <span>{item._count.comments} comments</span>
                    <span>{item._count.likes} likes • {item._count.dislikes} dislikes</span>
                    <span>{item._count.shares} shares</span>
                  </td>
                  <td>
                    <label className="switch-row">
                      <input
                        type="checkbox"
                        checked={item.commentsEnabled}
                        disabled={isDeleted}
                        onChange={(event) => onUpdateFeedItem(item, { commentsEnabled: event.currentTarget.checked })}
                      />
                      {item.commentsEnabled ? 'Enabled' : 'Off'}
                    </label>
                  </td>
                  <td>{item.status}</td>
                  <td>{formatDate(item.createdAt)}</td>
                  <td>
                    <div className="row-actions">
                      {previewUrl ? (
                        <a className="secondary-action compact-action action-link" href={previewUrl} target="_blank" rel="noreferrer">
                          Preview
                        </a>
                      ) : (
                        <span className="muted-text">No media</span>
                      )}
                      {isDeleted ? (
                        <span className="muted-text">Audit only</span>
                      ) : (
                        <>
                          <button
                            className={isBlocked ? 'secondary-action compact-action' : 'danger-action compact-action'}
                            type="button"
                            onClick={() => onUpdateFeedItem(item, { status: isBlocked ? 'PUBLISHED' : 'REJECTED' })}
                          >
                            {isBlocked ? 'Restore' : 'Block'}
                          </button>
                          <button
                            className="danger-action compact-action"
                            type="button"
                            onClick={() => onDeleteFeedItem(item)}
                          >
                            Delete
                          </button>
                        </>
                      )}
                    </div>
                  </td>
                </tr>
              );
            })}
          </tbody>
        </table>
      </section>
    </>
  );
}

function PlansView({
  plans,
  onSavePlan
}: {
  plans: SubscriptionPlan[];
  onSavePlan: (input: PlanInput, planId?: string) => void;
}) {
  const [editingPlan, setEditingPlan] = useState<SubscriptionPlan | null>(null);
  const [isCreating, setIsCreating] = useState(false);

  return (
    <>
      <div className="toolbar">
        <button className="primary-action compact-action" type="button" onClick={() => setIsCreating(true)}>
          <Plus size={16} /> Create plan
        </button>
      </div>
      {(isCreating || editingPlan) && (
        <PlanForm
          plan={editingPlan}
          onCancel={() => {
            setEditingPlan(null);
            setIsCreating(false);
          }}
          onSubmit={(input) => {
            onSavePlan(input, editingPlan?.id);
            setEditingPlan(null);
            setIsCreating(false);
          }}
        />
      )}
      {!plans.length ? (
        <section className="panel empty-state">No subscription plans yet.</section>
      ) : (
        <section className="panel table-panel">
          <table>
            <thead>
              <tr>
                <th>Plan</th>
                <th>Price</th>
                <th>Duration</th>
                <th>Status</th>
                <th>Actions</th>
              </tr>
            </thead>
            <tbody>
              {plans.map((plan) => (
                <tr key={plan.id}>
                  <td>
                    <strong>{plan.name}</strong>
                    <span>{plan.description ?? 'No description'}</span>
                  </td>
                  <td>{formatMoney(plan.priceCents, plan.currency)}</td>
                  <td>{plan.durationDays} days</td>
                  <td>{plan.isActive ? 'Active' : 'Disabled'}</td>
                  <td>
                    <button className="icon-action" type="button" onClick={() => setEditingPlan(plan)} title="Edit plan">
                      <Pencil size={16} />
                    </button>
                  </td>
                </tr>
              ))}
            </tbody>
          </table>
        </section>
      )}
    </>
  );
}

function PlanForm({
  plan,
  onCancel,
  onSubmit
}: {
  plan: SubscriptionPlan | null;
  onCancel: () => void;
  onSubmit: (input: PlanInput) => void;
}) {
  function handleSubmit(event: FormEvent<HTMLFormElement>) {
    event.preventDefault();
    const formData = new FormData(event.currentTarget);

    onSubmit({
      name: String(formData.get('name') ?? ''),
      description: String(formData.get('description') ?? ''),
      priceCents: Math.round(Number(formData.get('price') ?? 0) * 100),
      currency: String(formData.get('currency') ?? 'INR'),
      durationDays: Number(formData.get('durationDays') ?? 30),
      revenueCatOfferingId: String(formData.get('revenueCatOfferingId') ?? ''),
      revenueCatPackageId: String(formData.get('revenueCatPackageId') ?? ''),
      revenueCatEntitlementId: String(formData.get('revenueCatEntitlementId') ?? ''),
      isActive: formData.get('isActive') === 'on'
    });
  }

  return (
    <section className="panel user-form-panel">
      <h3>{plan ? 'Edit Plan' : 'Create Plan'}</h3>
      <form className="user-form" onSubmit={handleSubmit}>
        <label>
          Name
          <input name="name" defaultValue={plan?.name} required />
        </label>
        <label>
          Price
          <input name="price" type="number" min="0" step="0.01" defaultValue={plan ? plan.priceCents / 100 : ''} required />
        </label>
        <label>
          Currency
          <input name="currency" defaultValue={plan?.currency ?? 'INR'} required />
        </label>
        <label>
          Duration days
          <input name="durationDays" type="number" min="1" defaultValue={plan?.durationDays ?? 30} required />
        </label>
        <label>
          RevenueCat offering ID
          <input name="revenueCatOfferingId" defaultValue={plan?.revenueCatOfferingId ?? ''} />
        </label>
        <label>
          RevenueCat package ID
          <input name="revenueCatPackageId" defaultValue={plan?.revenueCatPackageId ?? ''} />
        </label>
        <label>
          RevenueCat entitlement ID
          <input name="revenueCatEntitlementId" defaultValue={plan?.revenueCatEntitlementId ?? ''} />
        </label>
        <label className="wide-field">
          Description
          <textarea name="description" defaultValue={plan?.description ?? ''} rows={3} />
        </label>
        <label className="checkbox-field">
          <input name="isActive" type="checkbox" defaultChecked={plan?.isActive ?? true} />
          Active
        </label>
        <div className="form-actions">
          <button className="primary-action compact-action" type="submit">
            Save plan
          </button>
          <button className="secondary-action" type="button" onClick={onCancel}>
            Cancel
          </button>
        </div>
      </form>
    </section>
  );
}

function PaymentsView({ events }: { events: PaymentEvent[] }) {
  if (!events.length) {
    return <section className="panel empty-state">No payment events yet.</section>;
  }

  return (
    <section className="panel table-panel">
      <table>
        <thead>
          <tr>
            <th>Provider</th>
            <th>Event</th>
            <th>User</th>
            <th>Subscription</th>
            <th>Processed</th>
          </tr>
        </thead>
        <tbody>
          {events.map((event) => (
            <tr key={event.id}>
              <td>{event.provider}</td>
              <td>
                <strong>{event.eventType}</strong>
                <span>{event.eventId}</span>
              </td>
              <td>
                {event.user ? (
                  <>
                    <strong>{event.user.displayName}</strong>
                    <span>@{event.user.username}</span>
                  </>
                ) : (
                  <span className="muted-text">Not linked</span>
                )}
              </td>
              <td>{event.subscriptionId ?? '-'}</td>
              <td>{formatDate(event.processedAt)}</td>
            </tr>
          ))}
        </tbody>
      </table>
    </section>
  );
}

function StorageView({
  cleanupResult,
  health,
  settings,
  onCleanup,
  onSave
}: {
  cleanupResult: StorageCleanupResult | null;
  health: StorageHealth | null;
  settings: StorageSettings | null;
  onCleanup: (dryRun: boolean) => void;
  onSave: (input: StorageSettingsInput) => void;
}) {
  const [provider, setProvider] = useState<'LOCAL' | 'R2'>(settings?.provider ?? 'LOCAL');

  useEffect(() => {
    setProvider(settings?.provider ?? 'LOCAL');
  }, [settings?.provider]);

  function handleSubmit(event: FormEvent<HTMLFormElement>) {
    event.preventDefault();
    const formData = new FormData(event.currentTarget);
    const r2SecretKey = String(formData.get('r2SecretKey') ?? '');

    onSave({
      provider,
      videoCompressionEnabled: formData.get('videoCompressionEnabled') === 'on',
      ...(provider === 'R2'
        ? {
            r2Bucket: String(formData.get('r2Bucket') ?? ''),
            r2Endpoint: String(formData.get('r2Endpoint') ?? ''),
            r2Region: String(formData.get('r2Region') ?? 'auto'),
            r2AccessKeyId: String(formData.get('r2AccessKeyId') ?? ''),
            ...(r2SecretKey ? { r2SecretKey } : {}),
            r2PublicUrl: String(formData.get('r2PublicUrl') ?? '')
          }
        : {})
    });
  }

  return (
    <>
      <section className="panel">
        <h3>Storage Health</h3>
        {health ? (
          <div className="summary-list">
            <span>Provider: {health.provider}</span>
            <span>Status: {health.healthy ? 'Healthy' : 'Needs attention'}</span>
            <span>Writable: {health.writable ? 'Yes' : 'No'}</span>
            <span>Public URL: {health.publicUrl ?? '-'}</span>
            {health.message ? <span>{health.message}</span> : null}
          </div>
        ) : (
          <p className="muted-text">Storage health has not been checked yet.</p>
        )}
      </section>
      <section className="panel user-form-panel">
        <h3>Storage Location</h3>
        <form className="user-form" onSubmit={handleSubmit}>
        <label>
          Provider
          <select name="provider" value={provider} onChange={(event) => setProvider(event.currentTarget.value as 'LOCAL' | 'R2')}>
            <option value="LOCAL">Local storage</option>
            <option value="R2">Cloudflare R2</option>
          </select>
        </label>
        <label className="checkbox-row wide-field">
          <input
            name="videoCompressionEnabled"
            type="checkbox"
            defaultChecked={settings?.videoCompressionEnabled ?? false}
          />
          <span>Compress videos before upload</span>
        </label>
        <label>
          R2 bucket
          <input name="r2Bucket" defaultValue={settings?.r2Bucket ?? ''} disabled={provider !== 'R2'} />
        </label>
        <label>
          R2 endpoint
          <input name="r2Endpoint" defaultValue={settings?.r2Endpoint ?? ''} disabled={provider !== 'R2'} />
        </label>
        <label>
          R2 region
          <input name="r2Region" defaultValue={settings?.r2Region ?? 'auto'} disabled={provider !== 'R2'} />
        </label>
        <label>
          R2 access key
          <input name="r2AccessKeyId" defaultValue={settings?.r2AccessKeyId ?? ''} disabled={provider !== 'R2'} />
        </label>
        <label>
          R2 secret key
          <input
            name="r2SecretKey"
            placeholder={settings?.r2SecretConfigured ? 'Already configured' : ''}
            disabled={provider !== 'R2'}
          />
        </label>
        <label className="wide-field">
          R2 public URL
          <input name="r2PublicUrl" defaultValue={settings?.r2PublicUrl ?? ''} disabled={provider !== 'R2'} />
        </label>
          <div className="form-actions">
            <button className="primary-action compact-action" type="submit">
              Save storage
            </button>
          </div>
        </form>
      </section>
      <section className="panel">
        <h3>Media Cleanup</h3>
        <p className="muted-text">
          Cleanup checks local files that are not linked to any media asset. Use dry run first.
        </p>
        <div className="form-actions">
          <button className="secondary-action compact-action" type="button" onClick={() => onCleanup(true)}>
            Dry run
          </button>
          <button className="danger-action compact-action" type="button" onClick={() => onCleanup(false)}>
            Delete orphaned local files
          </button>
        </div>
        {cleanupResult ? (
          <div className="summary-list">
            <span>Provider: {cleanupResult.provider}</span>
            <span>Dry run: {cleanupResult.dryRun ? 'Yes' : 'No'}</span>
            <span>Candidates: {cleanupResult.candidates}</span>
            <span>Deleted: {cleanupResult.deleted}</span>
            {cleanupResult.message ? <span>{cleanupResult.message}</span> : null}
          </div>
        ) : null}
      </section>
    </>
  );
}

function ProcessingView({ jobs }: { jobs: MediaProcessingJob[] }) {
  if (!jobs.length) {
    return <section className="panel empty-state">No processing jobs yet.</section>;
  }

  return (
    <section className="panel table-panel">
      <table>
        <thead>
          <tr>
            <th>Content</th>
            <th>Job</th>
            <th>Status</th>
            <th>Attempts</th>
            <th>Media</th>
            <th>Created</th>
            <th>Error</th>
          </tr>
        </thead>
        <tbody>
          {jobs.map((job) => {
            const mediaLink = mediaUrl(job.mediaAsset.publicUrl);
            return (
              <tr key={job.id}>
                <td>
                  <strong>{processingTargetTitle(job)}</strong>
                  <span>{processingTargetType(job)}</span>
                </td>
                <td>
                  <strong>{job.type.split('_').join(' ')}</strong>
                  <span>{job.id}</span>
                </td>
                <td>{job.status}</td>
                <td>
                  {job.attempts}/{job.maxAttempts}
                </td>
                <td>
                  <span>{job.mediaAsset.contentType}</span>
                  {mediaLink ? (
                    <a className="secondary-action compact-action action-link" href={mediaLink} target="_blank" rel="noreferrer">
                      Open
                    </a>
                  ) : (
                    <span className="muted-text">No URL</span>
                  )}
                </td>
                <td>{formatDate(job.createdAt)}</td>
                <td>{job.errorMessage ? <span>{job.errorMessage}</span> : <span className="muted-text">-</span>}</td>
              </tr>
            );
          })}
        </tbody>
      </table>
    </section>
  );
}

function AuditLogsView({
  actionFilter,
  logs,
  targetFilter,
  onActionFilterChange,
  onTargetFilterChange
}: {
  actionFilter: string;
  logs: AdminAuditLog[];
  targetFilter: string;
  onActionFilterChange: (value: string) => void;
  onTargetFilterChange: (value: string) => void;
}) {
  const actions = Array.from(new Set(logs.map((log) => log.action))).sort();

  return (
    <>
      <section className="panel">
        <form
          className="admin-form"
          onSubmit={(event) => {
            event.preventDefault();
            const formData = new FormData(event.currentTarget);
            onActionFilterChange(String(formData.get('action') ?? '').trim());
            onTargetFilterChange(String(formData.get('target') ?? '').trim());
          }}
        >
          <label>
            Action
            <input name="action" defaultValue={actionFilter} list="audit-actions" placeholder="REPORT_BLOCK_CONTENT" />
            <datalist id="audit-actions">
              {actions.map((action) => (
                <option key={action} value={action} />
              ))}
            </datalist>
          </label>
          <label>
            Target
            <input name="target" defaultValue={targetFilter} placeholder="USER:..." />
          </label>
          <div className="form-actions">
            <button className="primary-action compact-action" type="submit">
              Apply filters
            </button>
            <button
              className="secondary-action compact-action"
              type="button"
              onClick={() => {
                onActionFilterChange('');
                onTargetFilterChange('');
              }}
            >
              Clear
            </button>
          </div>
        </form>
      </section>
      {!logs.length ? (
        <section className="panel empty-state">No audit logs found.</section>
      ) : (
        <section className="panel table-panel">
          <table>
            <thead>
              <tr>
                <th>Action</th>
                <th>Admin</th>
                <th>Target</th>
                <th>Metadata</th>
                <th>Created</th>
              </tr>
            </thead>
            <tbody>
              {logs.map((log) => (
                <tr key={log.id}>
                  <td>
                    <strong>{log.action}</strong>
                    <span>{log.id}</span>
                  </td>
                  <td>
                    <strong>{log.admin.displayName}</strong>
                    <span>@{log.admin.username}</span>
                  </td>
                  <td>{log.target}</td>
                  <td>
                    <code className="metadata-code">{formatMetadata(log.metadata)}</code>
                  </td>
                  <td>{formatDate(log.createdAt)}</td>
                </tr>
              ))}
            </tbody>
          </table>
        </section>
      )}
    </>
  );
}

function LiveView({ liveRooms }: { liveRooms: AdminLiveRoom[] }) {
  const [nowMs, setNowMs] = useState(() => Date.now());
  const [viewersByRoom, setViewersByRoom] = useState<Record<string, LiveParticipant[]>>({});
  const [blockedViewersByRoom, setBlockedViewersByRoom] = useState<Record<string, LiveBlockedViewer[]>>({});
  const [loadingRoomId, setLoadingRoomId] = useState<string | null>(null);
  const [blockingViewerKey, setBlockingViewerKey] = useState<string | null>(null);
  const [unblockingViewerKey, setUnblockingViewerKey] = useState<string | null>(null);
  const [liveError, setLiveError] = useState('');
  const hasLiveRoom = liveRooms.some((room) => room.status === 'LIVE' && room.startedAt);

  useEffect(() => {
    if (!hasLiveRoom) {
      return;
    }

    const intervalId = window.setInterval(() => setNowMs(Date.now()), 1000);
    return () => window.clearInterval(intervalId);
  }, [hasLiveRoom]);

  if (!liveRooms.length) {
    return <section className="panel empty-state">No live rooms found.</section>;
  }

  async function loadViewers(roomId: string) {
    setLiveError('');
    setLoadingRoomId(roomId);

    try {
      const [viewers, blockedViewers] = await Promise.all([
        getLiveRoomParticipants(roomId),
        getLiveRoomBlocks(roomId)
      ]);
      setViewersByRoom((currentViewers) => ({
        ...currentViewers,
        [roomId]: viewers
      }));
      setBlockedViewersByRoom((currentViewers) => ({
        ...currentViewers,
        [roomId]: blockedViewers
      }));
    } catch (error) {
      setLiveError(error instanceof Error ? error.message : 'Unable to load live viewers');
    } finally {
      setLoadingRoomId(null);
    }
  }

  async function handleBlockViewer(roomId: string, viewer: LiveParticipant) {
    const username = viewer.user?.username ?? viewer.userId;
    const confirmed = window.confirm(`Block @${username} from this live room?`);

    if (!confirmed) {
      return;
    }

    setLiveError('');
    setBlockingViewerKey(`${roomId}:${viewer.userId}`);

    try {
      await blockLiveViewer(roomId, viewer.userId);
      setViewersByRoom((currentViewers) => ({
        ...currentViewers,
        [roomId]: (currentViewers[roomId] ?? []).filter((currentViewer) => currentViewer.userId !== viewer.userId)
      }));
      setBlockedViewersByRoom((currentViewers) => ({
        ...currentViewers,
        [roomId]: [
          {
            id: `${roomId}:${viewer.userId}`,
            userId: viewer.userId,
            createdAt: new Date().toISOString(),
            user: viewer.user
          },
          ...(currentViewers[roomId] ?? []).filter((currentViewer) => currentViewer.userId !== viewer.userId)
        ]
      }));
    } catch (error) {
      setLiveError(error instanceof Error ? error.message : 'Unable to block viewer');
    } finally {
      setBlockingViewerKey(null);
    }
  }

  async function handleUnblockViewer(roomId: string, viewer: LiveBlockedViewer) {
    const username = viewer.user?.username ?? viewer.userId;
    const confirmed = window.confirm(`Unblock @${username} for this live room?`);

    if (!confirmed) {
      return;
    }

    setLiveError('');
    setUnblockingViewerKey(`${roomId}:${viewer.userId}`);

    try {
      await unblockLiveViewer(roomId, viewer.userId);
      setBlockedViewersByRoom((currentViewers) => ({
        ...currentViewers,
        [roomId]: (currentViewers[roomId] ?? []).filter((currentViewer) => currentViewer.userId !== viewer.userId)
      }));
    } catch (error) {
      setLiveError(error instanceof Error ? error.message : 'Unable to unblock viewer');
    } finally {
      setUnblockingViewerKey(null);
    }
  }

  return (
    <section className="panel table-panel">
      {liveError && <p className="form-error">{liveError}</p>}
      <table>
        <thead>
          <tr>
            <th>Room</th>
            <th>User Live</th>
            <th>Status</th>
            <th>Started</th>
            <th>Ended</th>
            <th>Time Live</th>
            <th>Viewers</th>
            <th>Engagement</th>
            <th>Moderation</th>
          </tr>
        </thead>
        <tbody>
          {liveRooms.map((room) => {
            const durationSeconds = room.status === 'LIVE' && room.startedAt
              ? Math.max(0, Math.floor((nowMs - new Date(room.startedAt).getTime()) / 1000))
              : room.durationSeconds;
            const latestRecording = room.recordings[0];

            return (
              <tr key={room.id}>
                <td>
                  <strong>{room.title}</strong>
                  <span>
                    {room.recordingOn
                      ? 'Recording on'
                      : latestRecording
                        ? `Recording ${latestRecording.status.toLowerCase()}`
                        : 'Recording off'}
                  </span>
                  {latestRecording?.publicUrl && (
                    <a className="table-link" href={latestRecording.publicUrl} target="_blank" rel="noreferrer">
                      Open recording
                    </a>
                  )}
                  {latestRecording?.errorMessage && <span>{latestRecording.errorMessage}</span>}
                </td>
                <td>
                  <strong>{room.hostName}</strong>
                  <span>@{room.host.username}</span>
                </td>
                <td>{room.status}</td>
                <td>{room.startedAt ? formatDateTime(room.startedAt) : '-'}</td>
                <td>{room.endedAt ? formatDateTime(room.endedAt) : room.status === 'LIVE' ? 'Live now' : '-'}</td>
                <td>{formatDuration(durationSeconds)}</td>
                <td>
                  <strong>{room.currentViewerCount} current</strong>
                  <span>{room.peakViewerCount} peak</span>
                  <span>{room.uniqueViewerCount} unique · {room.totalViewerJoins} joins</span>
                </td>
                <td>
                  <strong>{room._count.comments} comments</strong>
                  <span>{room._count.reactions} reactions</span>
                </td>
                <td>
                  {room.status === 'LIVE' ? (
                    <div className="live-moderation-cell">
                      <button
                        className="secondary-action"
                        type="button"
                        disabled={loadingRoomId === room.id}
                        onClick={() => loadViewers(room.id)}
                      >
                        {loadingRoomId === room.id ? 'Loading' : 'Viewers'}
                      </button>
                      {(viewersByRoom[room.id] || blockedViewersByRoom[room.id]) && (
                        <div className="live-viewer-list">
                          <strong>Active viewers</strong>
                          {viewersByRoom[room.id]?.length ? (
                            viewersByRoom[room.id].map((viewer) => {
                              const username = viewer.user?.username ?? viewer.userId;
                              const displayName = viewer.user?.displayName ?? 'Viewer';
                              const viewerKey = `${room.id}:${viewer.userId}`;

                              return (
                                <div className="live-viewer-row" key={viewer.identity}>
                                  <span>
                                    <strong>{displayName}</strong>
                                    <small>@{username}</small>
                                  </span>
                                  <button
                                    className="icon-action danger-icon"
                                    type="button"
                                    title="Block viewer"
                                    disabled={blockingViewerKey === viewerKey}
                                    onClick={() => handleBlockViewer(room.id, viewer)}
                                  >
                                    <Ban size={16} />
                                  </button>
                                </div>
                              );
                            })
                          ) : (
                            <span className="muted-text">No active viewers</span>
                          )}
                          <strong>Blocked viewers</strong>
                          {blockedViewersByRoom[room.id]?.length ? (
                            blockedViewersByRoom[room.id].map((viewer) => {
                              const username = viewer.user?.username ?? viewer.userId;
                              const displayName = viewer.user?.displayName ?? 'Viewer';
                              const viewerKey = `${room.id}:${viewer.userId}`;

                              return (
                                <div className="live-viewer-row" key={viewer.id}>
                                  <span>
                                    <strong>{displayName}</strong>
                                    <small>@{username}</small>
                                  </span>
                                  <button
                                    className="secondary-action compact-action"
                                    type="button"
                                    disabled={unblockingViewerKey === viewerKey}
                                    onClick={() => handleUnblockViewer(room.id, viewer)}
                                  >
                                    Unblock
                                  </button>
                                </div>
                              );
                            })
                          ) : (
                            <span className="muted-text">No blocked viewers</span>
                          )}
                        </div>
                      )}
                    </div>
                  ) : (
                    <span className="muted-text">-</span>
                  )}
                </td>
              </tr>
            );
          })}
        </tbody>
      </table>
    </section>
  );
}

function viewTitle(view: AdminView) {
  const titles: Record<AdminView, string> = {
    dashboard: 'Dashboard',
    users: 'Users',
    plans: 'Subscription Plans',
    payments: 'Payments',
    storage: 'Storage',
    processing: 'Processing Queue',
    feed: 'Feed',
    reports: 'Reports',
    audit: 'Audit Logs',
    live: 'Live'
  };

  return titles[view];
}

function formatMoney(priceCents: number, currency: string) {
  return new Intl.NumberFormat(undefined, {
    style: 'currency',
    currency
  }).format(priceCents / 100);
}

function formatDate(value: string) {
  return new Intl.DateTimeFormat(undefined, {
    month: 'short',
    day: 'numeric',
    year: 'numeric'
  }).format(new Date(value));
}

function formatMetadata(value: unknown) {
  if (value === null || value === undefined) {
    return '-';
  }

  if (typeof value === 'string') {
    return value;
  }

  try {
    return JSON.stringify(value);
  } catch {
    return 'Metadata unavailable';
  }
}

function formatMediaDuration(durationMs: number) {
  const totalSeconds = Math.floor(durationMs / 1000);
  const minutes = Math.floor(totalSeconds / 60).toString().padStart(2, '0');
  const seconds = (totalSeconds % 60).toString().padStart(2, '0');
  return `${minutes}:${seconds}`;
}

function processingTargetTitle(job: MediaProcessingJob) {
  if (job.video) {
    return job.video.title;
  }

  if (job.reel) {
    return job.reel.caption || 'Reel';
  }

  if (job.liveRecording) {
    return job.liveRecording.room.title;
  }

  return job.mediaAsset.objectKey;
}

function processingTargetType(job: MediaProcessingJob) {
  if (job.video) {
    return `Video • ${job.video.status}`;
  }

  if (job.reel) {
    return `Reel • ${job.reel.status}`;
  }

  if (job.liveRecording) {
    return `Live recording • ${job.liveRecording.status}`;
  }

  return 'Media asset';
}

function mediaUrl(value: string | null) {
  if (!value) {
    return null;
  }

  if (value.startsWith('http://') || value.startsWith('https://')) {
    return value;
  }

  const apiUrl = import.meta.env.VITE_API_URL ?? 'http://localhost:4000/api';
  const apiOrigin = new URL(apiUrl).origin;
  return value.startsWith('/') ? `${apiOrigin}${value}` : `${apiOrigin}/${value}`;
}

function formatDateTime(value: string) {
  return new Intl.DateTimeFormat(undefined, {
    month: 'short',
    day: 'numeric',
    hour: 'numeric',
    minute: '2-digit'
  }).format(new Date(value));
}

function formatDuration(totalSeconds: number) {
  if (!totalSeconds) {
    return '-';
  }

  const hours = Math.floor(totalSeconds / 3600);
  const minutes = Math.floor((totalSeconds % 3600) / 60);
  const seconds = totalSeconds % 60;

  if (hours > 0) {
    return `${hours}h ${minutes}m`;
  }

  if (minutes > 0) {
    return `${minutes}m ${seconds}s`;
  }

  return `${seconds}s`;
}
