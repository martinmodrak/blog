#include /sum_nb_functions.stan

data {
  int<lower=1> N;
  int<lower=0> sums[N]; 
  int<lower=1> G;
  vector[G] mus;
  vector[G] phis;

  //0 - saddlepoint, 1 - method of moments
  int<lower = 0, upper = 1> method;
}

transformed data {
  real dummy_x_r[0];
}

parameters {
  real log_extra_mu_raw;
  real<lower=0> extra_phi_raw;
}

transformed parameters {
  real<lower=0> extra_mu = exp(log_extra_mu_raw * 3 + 5);
  real<lower=0> extra_phi =  inv(sqrt(extra_phi_raw));
}

model {
  vector[G + 1] all_mus = append_row(mus, to_vector({extra_mu}));
  vector[G + 1] all_phis = append_row(phis, to_vector({extra_phi}));

  if(method == 0) {
    sums ~ neg_binomial_sum_saddlepoint_lpmf(all_mus, all_phis, dummy_x_r);
  } else {
    sums ~ neg_binomial_sum_moments_lpmf(all_mus, all_phis);
  }

  log_extra_mu_raw ~ normal(0, 1);
  extra_phi_raw ~ normal(0,1);
}
