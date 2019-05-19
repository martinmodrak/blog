functions {
  //Compute upper bound on s - there is a singularity at this point
  real max_s(vector mus, vector phis) {
    return min(append_row(-log(mus) + log(mus + phis), log(phis ./ mus + 1)));
  }

  //Transform from unbounded y to s upper-bounded by max_s
  vector s_transform(vector y, vector mus, vector phis) {
    return -exp(y) + max_s(mus, phis);
  }

  vector nb_sum_log_Kd_eq(vector y, vector theta, real[] x_r, int[] x_i) {
    int G = rows(theta) / 2;
    int N = size(x_i);
    vector[G] log_mus = theta[1:G];
    vector[G] mus = exp(log_mus);
    vector[G] phis = theta[(G + 1) : (2 * G)];
    vector[N] s = s_transform(y, mus, phis);
    vector[N] sum_y = to_vector(x_i);
    vector[G] log_phis_mus = log(phis) + log_mus;
    vector[G] phis_mus = phis + mus;
    vector[N] value;
    for(n in 1:N) {
      value[n] = log_sum_exp(log_phis_mus + s[n] - log(phis_mus - mus * exp(s[n]))) - log(sum_y[n]);
    }
    return value;
  }

  real neg_binomial_sum_lpmf(int[] sum_y, vector mus, vector phis, real[] dummy_x_r) {
    int N = size(sum_y);
    //int G = rows(log_mus);
    //vector[G] mus = exp(log_mus);

    int G = rows(mus);
    vector[G] log_mus = log(mus);

    // Solve the saddlepoint equation
    vector[2 * G] solver_params = append_row(log_mus, phis);

    // ==== Unvectorized use of solver
    vector[N] s_vec_raw;
    vector[1] solver_guess = to_vector({0});
    for(n in 1:N) {
      s_vec_raw[n] = algebra_solver(nb_sum_log_Kd_eq, solver_guess, solver_params, dummy_x_r,  {sum_y[n]})[1];
    }

    // ==== Vectorized use of solver, seems a tiny bit faster, but maybe problematic for large N
    // vector[N] solver_guess = rep_vector(0, N);
    // vector[N] s_vec_raw = algebra_solver(nb_sum_log_Kd_eq, solver_guess, solver_params, dummy_x_r,  sum_y);

    {
      vector[N] s = s_transform(s_vec_raw, mus, phis);
      //Calculate the saddlepoint mass
      vector[N] K_s;
      vector[N] log_Kdd_s;

      for(n in 1:N) {
        vector[G] log_denominator_s = log(phis + mus - mus * exp(s[n]));
        K_s[n] = sum(phis .* (log(phis) - log_denominator_s));
        log_Kdd_s[n] = log_sum_exp(log(phis) + log_mus + log(phis + mus) + s[n] - 2 * log_denominator_s);
      }
      {
        real sum_lpmf = sum( -0.5 * (log(2*pi()) + log_Kdd_s) + K_s - s .* to_vector(sum_y) );

        return sum_lpmf;
      }
    }
  }

  real neg_binomial_sum_moments_lpmf(int[] sum_y, vector mus, vector phis) {
    real mu_approx = sum(mus);
    real phi_approx = square(mu_approx) / sum(square(mus) ./ phis);

    return neg_binomial_2_lpmf(sum_y | mu_approx, phi_approx);
  }
}

data {
  int<lower=1> N;
  int<lower=1> sums[N]; //The saddlepoint approximation breaks for 0
  int<lower=1> G;
  vector[G] mus;
  //vector[G + 1] phis;
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
  //vector[G + 1] all_phis = phis;
  if(method == 0) {
    sums ~ neg_binomial_sum_lpmf(all_mus, all_phis, dummy_x_r);
  } else {
    sums ~ neg_binomial_sum_moments_lpmf(all_mus, all_phis);
  }

  log_extra_mu_raw ~ normal(0, 1);
  extra_phi_raw ~ normal(0,1);
}
