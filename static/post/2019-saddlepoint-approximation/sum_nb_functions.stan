functions {
  //Compute upper bound on s - there is a singularity at this point
  real max_s(vector mus, vector phis) {
    return min(log(phis ./ mus + 1));
  }

  //Transform from unbounded y to s upper-bounded by max_s
  vector s_transform(vector y, vector mus, vector phis) {
    return -exp(y) + max_s(mus, phis);
  }

  vector nb_sum_log_Kd_eq(vector y, vector theta, real[] x_r, int[] x_i) {
    int G = rows(theta) / 2;
    vector[G] mus = theta[1:G];
    vector[G] phis = theta[(G + 1) : (2 * G)];

    real s = s_transform(y, mus, phis)[1];
    real sum_y = x_i[1];
    vector[G] log_phis_mus = log(phis) + log(mus);
    vector[G] phis_mus = phis + mus;
    
    real value = log_sum_exp(log_phis_mus + s - log(phis_mus - mus * exp(s))) - log(sum_y);
    return to_vector({value});
  }

  real neg_binomial_sum_saddlepoint_lpmf(int[] sum_y, vector mus, vector phis, data real[] dummy_x_r) {
    int N = size(sum_y);

    int G = rows(mus);

    // Solve the saddlepoint equation
    vector[2 * G] solver_params = append_row(mus, phis);

    vector[N] s_vec_raw;
    vector[1] solver_guess = to_vector({0});
    for(n in 1:N) {
      if(sum_y[n] != 0) {
        //Saddlepoint is defined only for non-zero values
        s_vec_raw[n] = algebra_solver(nb_sum_log_Kd_eq, solver_guess, solver_params, dummy_x_r,  {sum_y[n]})[1];
      } else {
        //This will be ignored, but needed to pass to s_transform without problems
        s_vec_raw[n] = 0;
      }
    }


    {
      vector[N] s = s_transform(s_vec_raw, mus, phis);
      //Calculate the saddlepoint mass
      vector[N] lpmf;
      vector[G] log_mus = log(mus);

      for(n in 1:N) {
        if(sum_y[n] != 0) {
          vector[G] log_denominator_s = log(phis + mus - mus * exp(s[n]));
          real K_s = sum(phis .* (log(phis) - log_denominator_s));
          real log_Kdd_s = log_sum_exp(log(phis) + log_mus + log(phis + mus) + s[n] - 2 * log_denominator_s);
          lpmf[n] = -0.5 * (log(2*pi()) + log_Kdd_s) + K_s - s[n] * sum_y[n] ;
        } else {
          //For zero values, the probability is simply that of all NBs giving 0 
          lpmf[n] = neg_binomial_2_lpmf(rep_array(0, G) | mus, phis);
        }
      }
      
      return sum(lpmf);
    }
  }
  
  real neg_binomial_sum_moments_lpmf(int[] sum_y, vector mus, vector phis) {
    real mu_approx = sum(mus);
    real phi_approx = square(mu_approx) / sum(square(mus) ./ phis);

    return neg_binomial_2_lpmf(sum_y | mu_approx, phi_approx);
  }
}
