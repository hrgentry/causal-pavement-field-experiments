functions {
  real cs_lpdf(vector z, vector mu, real sigma, real rho) {
    int n = rows(z);
    vector[n] r = z - mu;
    real a = 1 - rho;
    real b = 1 + (n - 1) * rho;
    if (n == 1) return normal_lpdf(z[1] | mu[1],sigma);
    return -0.5 * (n * log(2 * pi()) + 2 * n * log(sigma)
      + (n - 1) * log(a) + log(b)
      + dot_self(r-rep_vector(mean(r),n)) / (square(sigma)*a)
      + n*square(mean(r)) / (square(sigma)*b));
  }
  real mean_eta(real age, int j, int a, real anchor, real knot,
                real level, real common_age, real common_bend,
                vector arm0, vector arm_age, vector arm_bend,
                vector scales, vector project_z, vector slope_z, matrix treatment) {
    real t = (age-anchor)/5;
    real h = (fmax(age-knot,0)-fmax(anchor-knot,0))/5;
    return level+scales[1]*project_z[j]+(common_age+scales[3]*slope_z[j])*t+common_bend*h
      +arm0[a]+arm_age[a]*t+arm_bend[a]*h+scales[4]/sqrt(2.0)*treatment[j,a]*t;
  }
}
data {
  int<lower=1> N; int<lower=1> J; int<lower=1> S;
  vector<lower=0>[N] y; vector<lower=0>[N] age;
  array[N] int<lower=1,upper=J> project;
  array[N] int<lower=1,upper=S> section;
  array[N] int<lower=1,upper=3> arm;
  int<lower=1> D;
  array[D] int<lower=1,upper=N> group_first;
  array[D] int<lower=1,upper=3> group_size;
  array[N] int<lower=1,upper=N> grouped_rows;
  int<lower=1> M; vector<lower=0>[M] pred_age;
  array[M] int<lower=1,upper=J> pred_project;
  array[M] int<lower=1,upper=S> pred_section;
  array[M] int<lower=1,upper=3> pred_arm;
  int<lower=1> DP; array[M] int<lower=1,upper=DP> pred_date;
  array[J,3] int<lower=1,upper=S> cell_section;
  int<lower=1> JS; array[JS] int<lower=1,upper=J> supported_projects;
  real<lower=0> anchor_age; real<lower=0> knot_age;
  real level_mean; real<lower=0> level_sd; real<lower=0> arm0_sd;
  real<lower=0> age_sd; real<lower=0> bend_sd; vector<lower=0>[5] sd_scales;
  int<lower=0,upper=1> estimate_rho;
  real<lower=0,upper=0.999999> fixed_rho;
  real<lower=0> rho_prior_a; real<lower=0> rho_prior_b;
}
parameters {
  real level_z; real common_age_z; real common_bend_z;
  vector[3] arm0_z; vector[3] arm_age_z; vector[3] arm_bend_z;
  vector<lower=0>[5] scales;
  vector[J] z_project; vector[J] z_slope; vector[S] z_section;
  matrix[J,3] z_treatment;
  vector<lower=0,upper=1>[estimate_rho] rho_free;
}
transformed parameters {
  real level=level_mean+level_sd*level_z;
  real common_age=age_sd*common_age_z;
  real common_bend=bend_sd*common_bend_z;
  vector[3] arm0=arm0_sd*(arm0_z-mean(arm0_z));
  vector[3] arm_age=age_sd/sqrt(2.0)*(arm_age_z-mean(arm_age_z));
  vector[3] arm_bend=bend_sd/sqrt(2.0)*(arm_bend_z-mean(arm_bend_z));
  matrix[J,3] treatment;
  vector[N] eta_train;
  real rho = estimate_rho == 1 ? rho_free[1] : fixed_rho;
  for (j in 1:J) treatment[j]=z_treatment[j]-mean(z_treatment[j]);
  for (n in 1:N)
    eta_train[n]=mean_eta(age[n],project[n],arm[n],anchor_age,knot_age,level,common_age,common_bend,
      arm0,arm_age,arm_bend,scales,z_project,z_slope,treatment)+scales[2]*z_section[section[n]];
}
model {
  level_z ~ std_normal(); common_age_z ~ std_normal(); common_bend_z ~ std_normal();
  arm0_z ~ std_normal(); arm_age_z ~ std_normal(); arm_bend_z ~ std_normal();
  z_project ~ std_normal(); z_slope ~ std_normal(); z_section ~ std_normal();
  to_vector(z_treatment) ~ std_normal(); scales ~ normal(0,sd_scales);
  rho_free ~ beta(rho_prior_a,rho_prior_b);
  for (d in 1:D) {
    int nd = group_size[d];
    vector[nd] z; vector[nd] mu;
    for (i in 1:nd) {
      int n = grouped_rows[group_first[d]+i-1];
      z[i] = log(y[n]);
      mu[i] = eta_train[n] - square(scales[5])/2;
    }
    target += cs_lpdf(z | mu,scales[5],rho) - sum(z);
  }
}
generated quantities {
  matrix[J,3] mu_new5;
  matrix[J,3] mu_existing5;
  vector[2] delta_new6 = rep_vector(0,2);
  vector[2] delta_new_supported = rep_vector(0,2);
  vector[2] delta_existing_supported = rep_vector(0,2);
  vector[M] conditional_mean;
  vector[M] y_pred_mm;
  vector[DP] shared_residual;
  for (d in 1:DP) shared_residual[d] = rho > 0 ? normal_rng(0,scales[5]*sqrt(rho)) : 0;
  for (j in 1:J) {
    for (a in 1:3) {
      real f = mean_eta(5,j,a,anchor_age,knot_age,level,common_age,common_bend,
        arm0,arm_age,arm_bend,scales,z_project,z_slope,treatment);
      mu_new5[j,a] = exp(f+square(scales[2])/2);
      mu_existing5[j,a] = exp(f+scales[2]*z_section[cell_section[j,a]]);
    }
    for (k in 1:2) delta_new6[k] += (mu_new5[j,k+1]-mu_new5[j,1])/J;
  }
  for (s in 1:JS) {
    int j=supported_projects[s];
    for (k in 1:2) {
      delta_new_supported[k] += (mu_new5[j,k+1]-mu_new5[j,1])/JS;
      delta_existing_supported[k] += (mu_existing5[j,k+1]-mu_existing5[j,1])/JS;
    }
  }
  for (n in 1:M) {
    real eta=mean_eta(pred_age[n],pred_project[n],pred_arm[n],anchor_age,knot_age,level,common_age,common_bend,
      arm0,arm_age,arm_bend,scales,z_project,z_slope,treatment)+scales[2]*z_section[pred_section[n]];
    conditional_mean[n]=exp(eta);
    y_pred_mm[n]=exp(eta-square(scales[5])/2+shared_residual[pred_date[n]]
                        +normal_rng(0,scales[5]*sqrt(1-rho)));
  }
}
