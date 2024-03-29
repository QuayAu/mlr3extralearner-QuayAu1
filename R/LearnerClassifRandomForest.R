#' @title Classification Random Forest Learner
#'
#' @aliases mlr_learners_classif.randomForest
#' @format [R6::R6Class] inheriting from [LearnerClassif].
#'
#' @description
#' A [LearnerClassif] for a classification random forest implemented in randomForest::randomForest()] in package \CRANpkg{randomForest}.
#'
#' @references
#' Breiman, L. (2001).
#' Random Forests
#' Machine Learning
#' \url{https://doi.org/10.1023/A:1010933404324}
#'
#' @export
LearnerClassifRandomForest = R6Class("LearnerClassifRandomForest", inherit = LearnerClassif,
  public = list(
    initialize = function(id = "classif.randomForest") {
      super$initialize(
        id = id,
        packages = "randomForest",
        feature_types = c("numeric", "factor", "ordered"),
        predict_types = c("response", "prob"),
        param_set = ParamSet$new(
          params = list(
            ParamInt$new(id = "ntree", default = 500L, lower = 1L, tags = c("train", "predict")),
            ParamInt$new(id = "mtry", lower = 1L, tags = "train"),
            ParamLgl$new(id = "replace", default = TRUE, tags = "train"),
            ParamUty$new(id = "classwt", default = NULL, tags = "train"), #lower = 0
            ParamUty$new(id = "cutoff", tags = "train"), #lower = 0, upper = 1
            ParamUty$new(id = "strata", tags = "train"),
            ParamUty$new(id = "sampsize", tags = "train"), #lower = 1L
            ParamInt$new(id = "nodesize", default = 1L, lower = 1L, tags = "train"),
            ParamInt$new(id = "maxnodes", lower = 1L, tags = "train"),
            ParamFct$new(id = "importance", default = "accuracy", levels = c("accuracy", "gini", "none"), tag = "train"),
            ParamLgl$new(id = "localImp", default = FALSE, tags = "train"),
            ParamLgl$new(id = "proximity", default = FALSE, tags = "train"),
            ParamLgl$new(id = "oob.prox", tags = "train"), #requires = quote(proximity == TRUE)
            ParamLgl$new(id = "norm.votes", default = TRUE, tags = "train"),
            ParamLgl$new(id = "do.trace", default = FALSE, tags = "train"),
            ParamLgl$new(id = "keep.forest", default = TRUE, tags = "train"),
            ParamLgl$new(id = "keep.inbag", default = FALSE, tags = "train")
          )
        ),
        param_vals = list(importance = "accuracy"),
        properties = c("weights", "twoclass", "multiclass", "importance", "oob_error")
      )
    },

    train_internal = function(task) {
      pars = self$param_set$get_values(tags = "train")

      if (pars[["importance"]] != "none") {
        pars[["importance"]] = TRUE
      } else {
        pars[["importance"]] = FALSE
      }

      f = task$formula()
      data = task$data()
      levs = levels(data[[task$target_names]])
      n = length(levs)
      if (!"cutoff" %in% names(pars))
        cutoff = rep(1 / n, n)

      if ("classwt" %in% names(pars)) {
        classwt = pars[["classwt"]]
        if (is.numeric(classwt) && length(classwt) == n && is.null(names(classwt)))
          names(classwt) = levs
      } else {
        classwt = NULL
      }
      if (is.numeric(cutoff) && length(cutoff) == n && is.null(names(cutoff)))
        names(cutoff) = levs
      invoke(randomForest::randomForest, formula = f, data = data, classwt = classwt, cutoff = cutoff, .args = pars)
    },

    predict_internal = function(task) {
      pars = self$param_set$get_values(tags = "predict")
      newdata = task$data(cols = task$feature_names)
      type = ifelse(self$predict_type == "response", "response", "prob")

      p = invoke(predict, self$model, newdata = newdata,
        type = type, .args = pars)

      if (self$predict_type == "response") {
        list(response = p)
      } else {
        list(prob = p)
      }
    },

    importance = function() {
      if (is.null(self$model)) {
        stopf("No model stored")
      }
      imp = data.frame(self$model$importance)
      pars = self$param_set$get_values()
      if (pars[["importance"]] == "accuracy") {
        x = setNames(imp[["MeanDecreaseAccuracy"]], rownames(imp))
        return(sort(x, decreasing = TRUE))
      }
      if (pars[["importance"]] == "gini") {
        x = setNames(imp[["MeanDecreaseGini"]], rownames(imp))
        return(sort(x, decreasing = TRUE))
      }
    }
  )
)
