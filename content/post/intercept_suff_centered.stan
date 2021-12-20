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
  matrix[N_groups + 1, N_groups + 1] A;
  matrix[N_groups + 1, N_groups + 1] inv_A;
  real mu_alpha = 3;
  real sigma_alpha = 1;
  A[1:N_groups, 1:N_groups] = diag_matrix(rep_vector(1, N_groups));

  A[1,N_groups + 1] = -1;
  A[2:(N_groups + 1), N_groups + 1] = rep_vector(1, N_groups);
  A[N_groups + 1, 1] = 0;
  A[N_groups + 1, 2:N_groups] = rep_row_vector(-1, N_groups - 1);
  
  inv_A[1,1] = 1;
  inv_A[2:(N_groups + 1), 1] = rep_vector(0, N_groups);
  inv_A[1, 2:(N_groups + 1)] = rep_row_vector(inv(N_groups), N_groups);
  inv_A[N_groups + 1, 2:(N_groups + 1)] = rep_row_vector(inv(N_groups), N_groups);

  inv_A[2:N_groups, 2:(N_groups + 1)] = rep_matrix(-inv(N_groups), N_groups - 1, N_groups);
  for(g in 2:N_groups) {
    inv_A[g,g] = (N_groups - 1) * inv(N_groups);
  }

  if(max(fabs(to_vector(inv_A) - to_vector(inverse(A)))) > 1e-6) {
    print(inverse(A));
    print(inv_A);
    reject("Invalid inverse");
  }
  // print(inv_A);
  // print(quad_form(transpose(inv_A), diag_matrix(append_row([sigma_alpha]', rep_vector(0.283, N_groups)))));
}

parameters {
  real intercept_sweep;
  vector[N_groups - 1] group_r_raw; 
  real<lower=0> group_sd;
  //real mean_group_r_raw;
}

transformed parameters {
  vector[N_groups] group_r_sweep = sum_to_zero_QR(group_r_raw, groups_Q_r);
  //real mean_group_r = mean_group_r_raw * group_sd;
}

model {
  // Prior without mean_group_r
  matrix[N_groups + 1, N_groups + 1] prior_sigma =
    quad_form(diag_matrix(append_row([sigma_alpha^2]', rep_vector(group_sd^2, N_groups))), transpose(inv_A));
  append_row([intercept_sweep]', group_r_sweep[1:(N_groups - 1)]) ~
     multi_normal(append_row([mu_alpha]', rep_vector(0, N_groups - 1)), prior_sigma[1:N_groups, 1:N_groups]);
  
  //Prior with mean_group_r
  // matrix[N_groups + 1, N_groups + 1] prior_sigma_inv = 
  //   quad_form(diag_matrix(append_row([inv(sigma_alpha^2)]', rep_vector(inv(group_sd^2), N_groups))), A);
  // target += log(group_sd);  

  // append_row(append_row([intercept_sweep]', group_r_sweep[1:(N_groups - 1)]), mean_group_r) ~
  //   multi_normal_prec(append_row([mu_alpha]', rep_vector(0, N_groups)), prior_sigma_inv);
    
  group_sd ~ normal(0, 1);
  //y ~ poisson_log(intercept_sweep + group_r_sweep[groups]);
  target += poisson_log_lpmf(y | intercept_sweep + group_r_sweep[groups]);
}

generated quantities {
  real mean_group_r;
  vector[N_groups] group_r;
  real intercept;
  real m_R;
  real sigma_R;
  real sigma_R2;  
  
  {
    matrix[N_groups + 1, N_groups + 1] prior_sigma =
      quad_form(diag_matrix(append_row([sigma_alpha^2]', rep_vector(group_sd^2, N_groups))), transpose(inv_A));

    matrix[N_groups + 1, N_groups + 1] prior_sigma_inv =
      quad_form(diag_matrix(append_row([inv(sigma_alpha^2)]', rep_vector(inv(group_sd^2), N_groups))), A);

    

    m_R = prior_sigma[N_groups + 1, 2 : (N_groups + 1)] *
      inverse(prior_sigma[1:N_groups, 1:N_groups]) *
      append_row([intercept_sweep - mu_alpha]', group_r_sweep[1:(N_groups - 1)]);

    sigma_R = sqrt(inv(prior_sigma_inv[N_groups + 1, N_groups + 1]));
    sigma_R2 = sqrt(prior_sigma[N_groups + 1, N_groups + 1] -
      prior_sigma[N_groups + 1, 2 : (N_groups + 1)] *
      inverse(prior_sigma[1:N_groups, 1:N_groups]) *
      prior_sigma[2:(N_groups + 1), N_groups + 1]);

    
  }

  mean_group_r = normal_rng(m_R, sigma_R);
  group_r = group_r_sweep + mean_group_r;
  intercept = intercept_sweep - mean_group_r;
}
