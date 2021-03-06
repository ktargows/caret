#' Calculates performance across resamples
#' 
#' Given two numeric vectors of data, the mean squared error and R-squared are
#' calculated. For two factors, the overall agreement rate and Kappa are
#' determined.
#' 
#' \code{postResample} is meant to be used with \code{apply} across a matrix.
#' For numeric data the code checks to see if the standard deviation of either
#' vector is zero. If so, the correlation between those samples is assigned a
#' value of zero. \code{NA} values are ignored everywhere.
#' 
#' Note that many models have more predictors (or parameters) than data points,
#' so the typical mean squared error denominator (n - p) does not apply. Root
#' mean squared error is calculated using \code{sqrt(mean((pred - obs)^2}.
#' Also, \eqn{R^2} is calculated wither using as the square of the correlation
#' between the observed and predicted outcomes when \code{form = "corr"}. when
#' \code{form = "traditional"}, \deqn{ R^2 = 1-\frac{\sum (y_i -
#' \hat{y}_i)^2}{\sum (y_i - \bar{y}_i)^2} }
#' 
#' For \code{defaultSummary} is the default function to compute performance
#' metrics in \code{\link{train}}. It is a wrapper around \code{postResample}.
#' 
#' \code{twoClassSummary} computes sensitivity, specificity and the area under
#' the ROC curve. \code{mnLogLoss} computes the minus log-likelihood of the
#' multinomial distribution (without the constant term): \deqn{ -logLoss =
#' \frac{-1}{n}\sum_{i=1}^n \sum_{j=1}^C y_{ij} \log(p_{ij}) } where the
#' \code{y} values are binary indicators for the classes and \code{p} are the
#' predicted class probabilities.
#' 
#' \code{prSummary} (for precision and recall) computes values for the default
#' 0.50 probability cutoff as well as the area under the precision-recall curve
#' across all cutoffs and is labelled as \code{"AUC"} in the output. If assumes
#' that the first level of the factor variables corresponds to a relevant
#' result but the \code{lev} argument can be used to change this.
#' 
#' \code{multiClassSummary} computes some overall measures of for performance
#' (e.g. overall accuracy and the Kappa statistic) and several averages of
#' statistics calculated from "one-versus-all" configurations. For example, if
#' there are three classes, three sets of sensitivity values are determined and
#' the average is reported with the name ("Mean_Sensitivity"). The same is true
#' for a number of statistics generated by \code{\link{confusionMatrix}}. With
#' two classes, the basic sensitivity is reported with the name "Sensitivity"
#' 
#' To use \code{twoClassSummary} and/or \code{mnLogLoss}, the \code{classProbs}
#' argument of \code{\link{trainControl}} should be \code{TRUE}.
#' \code{multiClassSummary} can be used without class probabilities but some
#' statistics (e.g. overall log loss and the average of per-class area under
#' the ROC curves) will not be in the result set.
#' 
#' Other functions can be used via the \code{summaryFunction} argument of
#' \code{\link{trainControl}}. Custom functions must have the same arguments
#' as\code{defaultSummary}.
#' 
#' The function \code{getTrainPerf} returns a one row data frame with the
#' resampling results for the chosen model. The statistics will have the prefix
#' "\code{Train}" (i.e. "\code{TrainROC}"). There is also a column called
#' "\code{method}" that echoes the argument of the call to
#' \code{\link{trainControl}} of the same name.
#' 
#' @aliases postResample defaultSummary twoClassSummary prSummary getTrainPerf
#' mnLogLoss R2 RMSE multiClassSummary
#' @param pred A vector of numeric data (could be a factor)
#' @param obs A vector of numeric data (could be a factor)
#' @param data a data frame or matrix with columns \code{obs} and \code{pred}
#' for the observed and predicted outcomes. For \code{twoClassSummary}, columns
#' should also include predicted probabilities for each class. See the
#' \code{classProbs} argument to \code{\link{trainControl}}
#' @param lev a character vector of factors levels for the response. In
#' regression cases, this would be \code{NULL}.
#' @param model a character string for the model name (as taken form the
#' \code{method} argument of \code{\link{train}}.
#' @return A vector of performance estimates.
#' @author Max Kuhn, Zachary Mayer
#' @seealso \code{\link{trainControl}}
#' @references Kvalseth. Cautionary note about \eqn{R^2}. American Statistician
#' (1985) vol. 39 (4) pp. 279-285
#' @keywords utilities
#' @examples
#' 
#' predicted <-  matrix(rnorm(50), ncol = 5)
#' observed <- rnorm(10)
#' apply(predicted, 2, postResample, obs = observed)
#' 
#' classes <- c("class1", "class2")
#' set.seed(1)
#' dat <- data.frame(obs =  factor(sample(classes, 50, replace = TRUE)),
#'                   pred = factor(sample(classes, 50, replace = TRUE)),
#'                   class1 = runif(50), class2 = runif(50))
#' 
#' defaultSummary(dat, lev = classes)
#' twoClassSummary(dat, lev = classes)
#' prSummary(dat, lev = classes)
#' mnLogLoss(dat, lev = classes)
#' 
#' @export postResample
postResample <- function(pred, obs)
{

  isNA <- is.na(pred)
  pred <- pred[!isNA]
  obs <- obs[!isNA]

  if(!is.factor(obs) & is.numeric(obs))
    {
      if(length(obs) + length(pred) == 0)
        {
          out <- rep(NA, 2)
        } else {
          if(length(unique(pred)) < 2 || length(unique(obs)) < 2)
            {
              resamplCor <- NA
            } else {
              resamplCor <- try(cor(pred, obs, use = "pairwise.complete.obs"), silent = TRUE)
              if(class(resamplCor) == "try-error") resamplCor <- NA 
            }
          mse <- mean((pred - obs)^2)
          n <- length(obs)

          out <- c(sqrt(mse), resamplCor^2)
        }
      names(out) <- c("RMSE", "Rsquared")    
    } else {
      if(length(obs) + length(pred) == 0)
        {
          out <- rep(NA, 2)
        } else {
          pred <- factor(pred, levels = levels(obs))  
          requireNamespaceQuietStop("e1071")
          out <- unlist(e1071::classAgreement(table(obs, pred)))[c("diag", "kappa")]
        }
      names(out) <- c("Accuracy", "Kappa")         
    }
  if(any(is.nan(out))) out[is.nan(out)] <- NA
  out
}


#' @rdname postResample
#' @importFrom ModelMetrics auc
#' @export
twoClassSummary <- function (data, lev = NULL, model = NULL)
{
  lvls <- levels(data$obs)
  if(length(lvls) > 2)
    stop(paste("Your outcome has", length(lvls),
               "levels. The twoClassSummary() function isn't appropriate."))
  requireNamespaceQuietStop('ModelMetrics')
  if (!all(levels(data[, "pred"]) == lvls))
    stop("levels of observed and predicted data do not match")
  data$y = as.numeric(data$obs == lvls[2])
  rocAUC <- ModelMetrics::auc(ifelse(data$obs == lev[2], 0, 1), data[, lvls[1]])
  out <- c(rocAUC,
           sensitivity(data[, "pred"], data[, "obs"], lev[1]),
           specificity(data[, "pred"], data[, "obs"], lev[2]))
  names(out) <- c("ROC", "Sens", "Spec")
  out
}

#' @rdname postResample
#' @importFrom stats complete.cases
#' @export
mnLogLoss <- function(data, lev = NULL, model = NULL){
  if(is.null(lev)) stop("'lev' cannot be NULL")
  if(!all(lev %in% colnames(data)))
    stop("'data' should have columns consistent with 'lev'")
  if(!all(sort(lev) %in% sort(levels(data$obs))))
    stop("'data$obs' should have levels consistent with 'lev'")
  
  dataComplete <- data[complete.cases(data),]
  probs <- as.matrix(dataComplete[, lev, drop = FALSE])
  
  inds <- match(dataComplete$obs, colnames(probs))
  c(logLoss = ModelMetrics::mlogLoss(dataComplete$obs, probs))
}

#' @rdname postResample
#' @export
multiClassSummary <- function (data, lev = NULL, model = NULL){
  #Check data
  if (!all(levels(data[, "pred"]) == levels(data[, "obs"])))
    stop("levels of observed and predicted data do not match")
  has_class_probs <- all(lev %in% colnames(data))
  if(has_class_probs) {
    ## Overall multinomial loss
    lloss <- mnLogLoss(data = data, lev = lev, model = model)
    requireNamespaceQuietStop("ModelMetrics")
    #Calculate custom one-vs-all ROC curves for each class
    prob_stats <- lapply(levels(data[, "pred"]),
                         function(x){
                           #Grab one-vs-all data for the class
                           obs  <- ifelse(data[,  "obs"] == x, 1, 0)
                           prob <- data[,x]
                           AUCs <- try(ModelMetrics::auc(obs, data[,x]), silent = TRUE)
                           return(AUCs)
                         })
    roc_stats <- mean(unlist(prob_stats))
  }
  
  #Calculate confusion matrix-based statistics
  CM <- confusionMatrix(data[, "pred"], data[, "obs"])
  
  #Aggregate and average class-wise stats
  #Todo: add weights
  # RES: support two classes here as well
  #browser() # Debug
  if (length(levels(data[, "pred"])) == 2) {
    class_stats <- CM$byClass
  } else {
    class_stats <- colMeans(CM$byClass)
    names(class_stats) <- paste("Mean", names(class_stats))
  }
  
  # Aggregate overall stats
  overall_stats <- if(has_class_probs)
    c(CM$overall, logLoss = lloss, ROC = roc_stats) else CM$overall
  if (length(levels(data[, "pred"])) > 2)
    names(overall_stats)[names(overall_stats) == "ROC"] <- "Mean_AUC"
  
  
  # Combine overall with class-wise stats and remove some stats we don't want
  stats <- c(overall_stats, class_stats)
  stats <- stats[! names(stats) %in% c('AccuracyNull', "AccuracyLower", "AccuracyUpper",
                                       "AccuracyPValue", "McnemarPValue",
                                       'Mean Prevalence', 'Mean Detection Prevalence')]
  
  # Clean names
  names(stats) <- gsub('[[:blank:]]+', '_', names(stats))
  
  # Change name ordering to place most useful first
  # May want to remove some of these eventually
  stat_list <- c("Accuracy", "Kappa", "Mean_Sensitivity", "Mean_Specificity",
                 "Mean_Pos_Pred_Value", "Mean_Neg_Pred_Value", "Mean_Detection_Rate",
                 "Mean_Balanced_Accuracy")
  if(has_class_probs) stat_list <- c("logLoss", "Mean_AUC", stat_list)
  if (length(levels(data[, "pred"])) == 2) stat_list <- gsub("^Mean_", "", stat_list)
  
  stats <- stats[c(stat_list)]
  
  return(stats)
}
