functions {
  vector Q_sum_to_zero_QR(int N) {
    vector [2*N] Q_r;

    for(i in 1:N) {
      Q_r[i] = -sqrt((N-i)/(N-i+1.0));
      Q_r[i+N] = inv_sqrt((N-i) * (N-i+1));
    }
    Q_r = Q_r * inv_sqrt(1 - inv(N));
    return Q_r;
  }

  vector sum_to_zero_QR(vector x_raw, vector Q_r) {
    int N = num_elements(x_raw) + 1;
    vector [N] x;
    real x_aux = 0;

    for(i in 1:N-1){
      x[i] = x_aux + x_raw[i] * Q_r[i];
      x_aux = x_aux + x_raw[i] * Q_r[i+N];
    }
    x[N] = x_aux;
    return x;
  }
}

data {
  int<lower=0> N;
  int<lower=1> N_groups;
  int<lower=1,upper=N_groups> groups[N];
  int<lower=0> y[N];
}

transformed data {
  vector[2 * N_groups] groups_Q_r = Q_sum_to_zero_QR(N_groups);
  matrix[N_groups + 1, N_groups + 1] inv_A;
  real mu_alpha = 3;
  real sigma_alpha = 1;

  inv_A[1,1] = 1;
  inv_A[2:(N_groups + 1), 1] = rep_vector(0, N_groups);
  inv_A[1, 2:(N_groups + 1)] = rep_row_vector(inv(N_groups), N_groups);
  inv_A[N_groups + 1, 2:(N_groups + 1)] = rep_row_vector(inv(N_groups), N_groups);

  inv_A[2:N_groups, 2:(N_groups + 1)] = rep_matrix(-inv(N_groups), N_groups - 1, N_groups);
  for(g in 2:N_groups) {
    inv_A[g,g] = (N_groups - 1) * inv(N_groups);
  }
}

parameters {
  real intercept_sweep;
  vector[N_groups - 1] group_r_raw; 
  real<lower=0> group_sd;
}

transformed parameters {
  vector[N_groups] group_r_sweep = sum_to_zero_QR(group_r_raw, groups_Q_r);
}

model {
  matrix[N_groups + 1, N_groups + 1] prior_sigma =
    quad_form(diag_matrix(append_row([sigma_alpha^2]', rep_vector(group_sd^2, N_groups))), transpose(inv_A));
  
  vector[N_groups + 1] intercept_and_groups = append_row([intercept_sweep]', group_r_sweep[1:(N_groups - 1)]);
   
  target += multi_normal_lpdf(intercept_and_groups | 
       append_row([mu_alpha]', rep_vector(0, N_groups - 1)), 
       prior_sigma[1:N_groups, 1:N_groups]);
  
  target += normal_lpdf(group_sd | 0, 1);
  target += poisson_log_lpmf(y | intercept_sweep + group_r_sweep[groups]);
}

generated quantities {
  real mean_group_r;
  vector[N_groups] group_r;
  real intercept;
  real m_R;
  real sigma_R;
  
  m_R = (intercept_sweep - mu_alpha)*(group_sd^2) / (N_groups * sigma_alpha^2 + group_sd^2);
  sigma_R = sqrt(inv(inv(sigma_alpha^2) + N_groups / (group_sd ^ 2)));

  mean_group_r = normal_rng(m_R, sigma_R);
  group_r = group_r_sweep + mean_group_r;
  intercept = intercept_sweep - mean_group_r;
}
