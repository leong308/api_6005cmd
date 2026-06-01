const { createApp } = require("./app");
const { env } = require("./config/env");
const { globalErrorHandler } = require("./middleware/errorHandler");
const { notFoundHandler } = require("./middleware/error-handler");
const { summaryRouter } = require("./routes/summaryRoutes");

const app = createApp();

// Standalone summary routes
app.use("/api/trips", summaryRouter);

// Fallback for page/route not found
app.use(notFoundHandler);

// Global error handler placed at the bottom, after all routes/middlewares
app.use(globalErrorHandler);

app.listen(env.port, () => {
  console.log(`Smart Travel Planner API listening on http://localhost:${env.port}`);
});

