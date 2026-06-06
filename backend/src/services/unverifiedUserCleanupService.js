const {
  deleteExpiredUnverifiedUsers,
} = require("../data/repository");

const DEFAULT_CLEANUP_INTERVAL_MS = 10 * 60 * 1000;
const CLEANUP_INTERVAL_MS = readCleanupIntervalMs();

let cleanupTimer = null;

async function cleanupExpiredUnverifiedUsers() {
  const deletedCount = await deleteExpiredUnverifiedUsers(new Date());
  if (deletedCount > 0) {
    console.info(`Deleted ${deletedCount} expired unverified account(s).`);
  }
  return deletedCount;
}

function startExpiredUnverifiedUserCleanup() {
  if (cleanupTimer) {
    return cleanupTimer;
  }

  cleanupExpiredUnverifiedUsers().catch((error) => {
    console.error(`Expired account cleanup failed: ${error.message}`);
  });

  cleanupTimer = setInterval(() => {
    cleanupExpiredUnverifiedUsers().catch((error) => {
      console.error(`Expired account cleanup failed: ${error.message}`);
    });
  }, CLEANUP_INTERVAL_MS);
  cleanupTimer.unref?.();
  return cleanupTimer;
}

function stopExpiredUnverifiedUserCleanup() {
  if (!cleanupTimer) {
    return;
  }
  clearInterval(cleanupTimer);
  cleanupTimer = null;
}

function readCleanupIntervalMs() {
  const configured = Number(process.env.UNVERIFIED_ACCOUNT_CLEANUP_INTERVAL_MS);
  return Number.isFinite(configured) && configured > 0
    ? configured
    : DEFAULT_CLEANUP_INTERVAL_MS;
}

module.exports = {
  cleanupExpiredUnverifiedUsers,
  startExpiredUnverifiedUserCleanup,
  stopExpiredUnverifiedUserCleanup,
};
