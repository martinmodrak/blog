data {
  int<lower=1,upper=2> N;
  int<lower=1> N_trials;
  array[N] int<lower=0, upper=N_trials> y;
  int<lower=0, upper=N_trials> stop_low;
  int<lower=0, upper=N_trials> stop_high;
}

//TODO test data

parameters {
  real<lower=0,upper=1> theta;
}

transformed parameters {
    real log_prob_stopped = log_sum_exp(
      binomial_lcdf(stop_low | N_trials, theta),
      binomial_lccdf(stop_high - 1 | N_trials, theta)
    );
}

model {
  target += binomial_lpmf(y | N_trials, theta);
  if(N == 1) {
    target += -log_prob_stopped;
  } else {
    target += -log1m_exp(log_prob_stopped);
  }
}

