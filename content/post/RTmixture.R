# Implementation of contaminated response time distribution. Idea by 
# Nathaniel Haines (https://twitter.com/Nate__Haines), code by Martin Modrák.
# License: BSD 2-clause (https://opensource.org/licenses/BSD-2-Clause)
# Please acknowledge when used in academic publications. I'll be happy to hear
# about all your success (and struggles as well)
# 
# Some background, discussion and examples at 
# http://www.martinmodrak.cz/2021/04/01/using-brms-to-model-reaction-times-contaminated-with-errors/


# The START and END comments are used by the blog to show relevant sections of 
# the file.

# START: RNG
rRTmixture <- function(n, meanlog, sdlog, mix, shift, upper) {
  ifelse(runif(n) < mix, 
         runif(n, 0, upper), 
         shift + rlnorm(n, meanlog = meanlog, sdlog = sdlog))
}

# END: RNG

# START: BASE
stan_funs_base <- stanvar(block = "functions", scode = "
  real RTmixture_lpdf(real y, real mu, real sigma, real mix, 
                      real shiftprop, real max_shift, real upper) {
    real shift = shiftprop * max_shift;
    if(y <= shift) {
      // Could only be created by the contamination
      return log(mix) + uniform_lpdf(y | 0, upper);
    } else if(y >= upper) {
      // Could only come from the lognormal
      return log1m(mix) + lognormal_lpdf(y - shift | mu, sigma);
    } else {
      // Actually mixing
      real lognormal_llh = lognormal_lpdf(y - shift | mu, sigma);
      real uniform_llh = uniform_lpdf(y | 0, upper);
      return log_mix(mix, uniform_llh, lognormal_llh);
    }
  }

")



RTmixture <- custom_family(
  "RTmixture", 
  dpars = c("mu", "sigma", "mix", "shiftprop"), # Those will be estimated
  links = c("identity", "log", "logit", "logit"),
  type = "real",
  lb = c(NA, 0, 0, 0), # bounds for the parameters 
  ub = c(NA, NA, 1, 1),
  vars = c("vreal1[n]", "vreal2[n]") # Data for max_shift and upper (known)
)
# END: BASE


# START: CDF

stan_funs <- stan_funs_base + stanvar(block = "functions", scode = "
  real RTmixture_lcdf(real y, real mu, real sigma, real mix, 
                      real shiftprop, real max_shift, real upper) {
    real shift = shiftprop * max_shift;
    if(y <= shift) {
      return log(mix) + uniform_lcdf(y | 0, upper);
    } else if(y >= upper) {
      // The whole uniform part is below, so the mixture part is log(1) = 0
      return log_mix(mix, 0, lognormal_lcdf(y - shift | mu, sigma));
    } else {
      real lognormal_llh = lognormal_lcdf(y - shift | mu, sigma);
      real uniform_llh = uniform_lcdf(y | 0, upper);
      return log_mix(mix, uniform_llh, lognormal_llh);
    }
  }
  
  real RTmixture_lccdf(real y, real mu, real sigma, real mix, 
                      real shiftprop, real max_shift, real upper) {

    real shift = shiftprop * max_shift;
    if(y <= shift) {
      // The whole lognormal part is above, so the mixture part is log(1) = 0
      return log_mix(mix, uniform_lccdf(y | 0, upper), 0);
    } else if(y >= upper) {
      return log1m(mix) + lognormal_lccdf(y - shift | mu, sigma);
    } else {
      real lognormal_llh = lognormal_lccdf(y - shift | mu, sigma);
      real uniform_llh = uniform_lccdf(y | 0, upper);
      return log_mix(mix, uniform_llh, lognormal_llh);
    }

  }
")

# END: CDF



# START: PREDICT

posterior_predict_RTmixture <- function(i, prep, ...) {
  if((!is.null(prep$data$lb) && prep$data$lb[i] > 0) || 
     (!is.null(prep$data$ub) && prep$data$ub[i] < Inf)) {
    stop("Predictions for truncated distributions not supported")
  }  
  
  mu <- brms:::get_dpar(prep, "mu", i = i)
  sigma <- brms:::get_dpar(prep, "sigma", i = i)
  mix <- brms:::get_dpar(prep, "mix", i = i)
  shiftprop <- brms:::get_dpar(prep, "shiftprop", i = i)
  
  max_shift <- prep$data$vreal1[i]
  upper <- prep$data$vreal2[i]
  shift = shiftprop * max_shift
  
  rRTmixture(prep$nsamples, meanlog = mu, sdlog = sigma, 
             mix = mix, shift = shift, upper = upper)
}

# END: PREDICT

# START: LOGLIK
## Needed for numerical stability
## from http://tr.im/hH5A
logsumexp <- function (x) {
  y = max(x)
  y + log(sum(exp(x - y)))
}


RTmixture_lpdf <- function(y, meanlog, sdlog, mix, shift, upper) {
  unif_llh = dunif(y , min = 0, max = upper, log = TRUE)
  lognormal_llh = dlnorm(y - shift, meanlog = meanlog, sdlog = sdlog, log = TRUE) - 
    plnorm(upper - shift, meanlog = meanlog, sdlog = sdlog, log.p = TRUE)
  
  
  # Computing logsumexp(log(mix) + unif_llh, log1p(-mix) + lognormal_llh)    
  # but vectorized
  llh_matrix <- array(NA_real_, dim = c(2, max(length(unif_llh), length(lognormal_llh))))
  llh_matrix[1,] <- log(mix) + unif_llh
  llh_matrix[2,] <- log1p(-mix) + lognormal_llh
  apply(llh_matrix, MARGIN = 2, FUN = logsumexp)
}

log_lik_RTmixture <- function(i, draws) {
  mu <- brms:::get_dpar(draws, "mu", i = i)
  sigma <- brms:::get_dpar(draws, "sigma", i = i)
  mix <- brms:::get_dpar(draws, "mix", i = i)
  shiftprop <- brms:::get_dpar(draws, "shiftprop", i = i)
  
  max_shift <- draws$data$vreal1[i]
  upper <- draws$data$vreal2[i]
  shift = shiftprop * max_shift
  
  y <- draws$data$Y[i]
  RTmixture_lpdf(y, meanlog = mu, sdlog = sigma, 
                 mix = mix, shift = shift, upper = upper)
  
}
# END: LOGLIK
