# A model is a fit object plus a predict function. Algorithms run sequentially.
# Tuning uses validation MAE only. Test rows are not supplied to this module.

#' Fit one named regression method and return a uniform prediction adapter.
fit_algorithm <- function(name, x, y, xv, yv) {
  df <- data.frame(y = y, x, check.names = FALSE)
  wrapper <- function(object, fun, tuning = list())
    list(object = object, predict = fun, tuning = tuning)
  choose <- function(candidates) {
    errors <- vapply(candidates, function(m) mean(abs(yv - m$predict(xv))), numeric(1))
    candidates[[which.min(errors)]]
  }
  if (name == 'OLS') {
    fit <- stats::lm.fit(cbind(Intercept = 1, x), y)
    beta <- fit$coefficients
    beta[is.na(beta)] <- 0
    return(wrapper(beta, function(z) as.numeric(cbind(1, z) %*% beta)))
  }
  if (name %in% c('Ridge', 'Lasso', 'ElasticNet')) {
    alpha <- switch(name, Ridge = 0, Lasso = 1, ElasticNet = .5)
    fit <- glmnet::glmnet(x, y, alpha = alpha, standardize = FALSE)
    p <- predict(fit, newx = xv)
    errors <- colMeans(abs(sweep(p, 1, yv, '-')))
    lambda <- fit$lambda[which.min(errors)]
    return(wrapper(fit, function(z) as.numeric(predict(fit, newx = z, s = lambda)),
                   list(alpha = alpha, lambda = lambda)))
  }
  if (name == 'CART') return(choose(lapply(c(.005, .02), function(cp) {
    fit <- rpart::rpart(y ~ ., data = df, method = 'anova',
      control = rpart::rpart.control(cp = cp, maxdepth = 8L, minsplit = 30L, xval = 0L))
    wrapper(fit, function(z) as.numeric(predict(fit, data.frame(z))), list(cp = cp))
  })))
  if (name %in% c('RandomForest', 'ExtraTrees')) return(choose(lapply(c(10L, 30L), function(node) {
    fit <- ranger::ranger(y ~ ., data = df, num.trees = if (SMOKE) 40L else 150L,
      mtry = max(1L, floor(sqrt(ncol(x)))), min.node.size = node,
      splitrule = if (name == 'ExtraTrees') 'extratrees' else 'variance',
      max.depth = 12L, num.threads = THREADS, seed = SEED, write.forest = TRUE)
    wrapper(fit, function(z) as.numeric(predict(fit, data.frame(z), num.threads = THREADS)$predictions),
            list(min_node = node))
  })))
  if (name == 'GBM') return(choose(lapply(c(2L, 4L), function(depth) {
    trees <- if (SMOKE) 50L else 200L
    fit <- gbm::gbm(y ~ ., data = df, distribution = 'gaussian',
      n.trees = trees, interaction.depth = depth, shrinkage = .05,
      n.minobsinnode = 20L, bag.fraction = .8, verbose = FALSE, keep.data = FALSE)
    wrapper(fit, function(z) as.numeric(predict(fit, data.frame(z), n.trees = trees)),
            list(depth = depth, trees = trees))
  })))
  if (name == 'XGBoost') return(choose(lapply(c(3L, 5L), function(depth) {
    dx <- xgboost::xgb.DMatrix(x, label = y)
    dv <- xgboost::xgb.DMatrix(xv, label = yv)
    args <- list(params = list(objective = 'reg:squarederror', eval_metric = 'mae',
      max_depth = depth, eta = .05, tree_method = 'hist', nthread = THREADS,
      subsample = .8, colsample_bytree = .8, seed = SEED),
      data = dx, nrounds = if (SMOKE) 50L else 250L,
      early_stopping_rounds = 20L, verbose = 0L)
    # Current XGBoost uses evals; older installations use watchlist.
    eval_arg <- if ('evals' %in% names(formals(xgboost::xgb.train))) 'evals' else 'watchlist'
    args[[eval_arg]] <- list(validation = dv)
    fit <- do.call(xgboost::xgb.train, args)
    wrapper(fit, function(z) as.numeric(predict(fit, xgboost::xgb.DMatrix(z))), list(depth = depth))
  })))
  if (name == 'MARS') return(choose(lapply(c(1L, 2L), function(degree) {
    fit <- earth::earth(x = x, y = y, degree = degree, nprune = 25L, nk = 40L, trace = 0L)
    wrapper(fit, function(z) as.numeric(predict(fit, z)), list(degree = degree))
  })))
  if (name == 'GAM') {
    # Smooth at most four nonconstant continuous features; remaining columns are linear.
    smooth <- intersect(c('log_distance', 'seconds', 'att_pos_x', 'att_pos_y'), colnames(x))
    smooth <- smooth[vapply(smooth, function(col) length(unique(x[, col])) >= 6L, logical(1))]
    linear <- setdiff(colnames(x), smooth)
    terms <- c(sprintf('s(%s, k=6)', smooth), linear)
    form <- stats::as.formula(paste('y ~', paste(terms, collapse = ' + ')))
    environment(form) <- asNamespace('mgcv')
    fit <- mgcv::bam(form, data = df, method = 'fREML', discrete = TRUE, nthreads = THREADS)
    # Exact prediction avoids bam's batch-dependent newdata discretization:
    # scoring a row alone must agree with scoring it in the full test matrix.
    return(wrapper(fit, function(z) as.numeric(predict(fit, data.frame(z), discrete = FALSE))))
  }
  if (name == 'NeuralNet') return(choose(lapply(c(5L, 10L), function(size) {
    target_center <- mean(y)
    target_scale <- stats::sd(y)
    fit <- nnet::nnet(x, (y - target_center) / target_scale,
      size = size, linout = TRUE, decay = .05, maxit = 150L, trace = FALSE, MaxNWts = 10000L)
    wrapper(fit, function(z) as.numeric(predict(fit, z)) * target_scale + target_center,
            list(size = size))
  })))
  stop('Unknown algorithm: ', name)
}
ALGORITHMS <- c('OLS', 'Ridge', 'Lasso', 'ElasticNet', 'CART', 'RandomForest',
                'ExtraTrees', 'GBM', 'XGBoost', 'MARS', 'GAM', 'NeuralNet')
