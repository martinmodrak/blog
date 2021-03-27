
data {
  int K;
  vector[K] y;
}

parameters {
  real<lower=0, upper=1> s;
  real alpha;
}

transformed parameters {
  real log_lik_null = normal_lpdf(y | 0, 1);
  real log_lik_intercept = normal_lpdf(y | alpha, 1);
}

model {
    target += log_mix(s, log_lik_null, log_lik_intercept);
    target += normal_lpdf(alpha | 0, 2);
}