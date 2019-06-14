#include /sum_nb_functions.stan

data {
  int<lower=1> N;
  int<lower=0> sums[N]; 
  int<lower=1> G;

  //0 - saddlepoint, 1 - method of moments
  int<lower = 0, upper = 1> method;
  
  real mu_prior_mean;
  real<lower = 0> mu_prior_sd;
  
  real<lower=0> mu_series_coeff;
  real<lower=0> phi_series_coeff;
}

transformed data {
  real dummy_x_r[0];
  vector[G] mu_coeffs;
  vector[G] phi_coeffs;
  
  mu_coeffs[1] = 1;
  phi_coeffs[1] = 1;
  for(g in 2:G) {
    mu_coeffs[g] = mu_coeffs[g - 1] * mu_series_coeff;
    phi_coeffs[g] = phi_coeffs[g - 1] * phi_series_coeff;
  }
}

parameters {
  real log_mu_raw;
  real<lower=0> phi_raw;
}

transformed parameters {
  real<lower=0> mu = exp(log_mu_raw * mu_prior_sd + mu_prior_mean);
  real<lower=0> phi =  inv(sqrt(phi_raw));
}

model {
  vector[G] all_mus = mu * mu_coeffs;
  vector[G] all_phis = phi * phi_coeffs;

  if(method == 0) {
    sums ~ neg_binomial_sum_saddlepoint_lpmf(all_mus, all_phis, dummy_x_r);
  } else {
    sums ~ neg_binomial_sum_moments_lpmf(all_mus, all_phis);
  }

  log_mu_raw ~ normal(0, 1);
  phi_raw ~ normal(0,1);
}
