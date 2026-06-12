const {
  deleteExpiredUnverifiedUsers,
} = require("../data/repository");
const { isMongoConfigured } = require("../db/mongo");

const DEFAULT_CLEANUP_INTERVAL_MS = 10 * 60 * 1000;
const CLEANUP_INTERVAL_MS = readCleanupIntervalMs();

let cleanupTimer = null;

/**
 * Supports the cleanup expired unverified users backend flow.
 */
async function cleanupExpiredUnverifiedUsers() {
  const deletedCount = await deleteExpiredUnverifiedUsers(new Date());
  if (deletedCount > 0) {
    console.info(`Deleted ${deletedCount} expired unverified account(s).`);
  }
  return deletedCount;
}

/**
 * Supports the start expired unverified user cleanup backend flow.
 */
function startExpiredUnverifiedUserCleanup() {
  if (cleanupTimer) {
    return cleanupTimer;
  }

  if (!isMongoConfigured()) {
    // In-memory store does not persist across restarts; skip cleanup scheduling.
    return null;
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

/**
 * Supports the stop expired unverified user cleanup backend flow.
 */
function stopExpiredUnverifiedUserCleanup() {
  if (!cleanupTimer) {
    return;
  }
  clearInterval(cleanupTimer);
  cleanupTimer = null;
}

/**
 * Reads the cleanup interval ms value from configuration or input.
 */
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
