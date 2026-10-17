data {
  int<lower=1> N; int<lower=1> C; int<lower=1> G;
  array[N] int<lower=1,upper=C> campaign;
  array[N] int<lower=1,upper=8> section;
  array[G] int<lower=1,upper=N> first;
  array[G] int<lower=1> size;
  vector[N] age; vector[N] log_y; matrix[8,7] X;
  array[N] int<lower=0> crack_count; array[N] int<lower=0> seal_count;
  int<lower=0,upper=1> bend_mean; int<lower=0,upper=1> event_kernel;
  real knot1; real knot2;
  real<lower=0> ell_median; real<lower=0> ell_log_sd;
  real<lower=0> kappa_a; real<lower=0> kappa_b;
  int<lower=0,upper=1> rounded_likelihood;
  vector[N*rounded_likelihood] log_lower; vector[N*rounded_likelihood] log_upper;
  int<lower=1> CE; array[CE] int<lower=1,upper=C> eval_campaign;
  vector[CE] eval_age;
}
parameters {
  vector<lower=log_lower,upper=log_upper>[N*rounded_likelihood] log_latent;
  vector[C] alpha;
  vector[7] beta; vector[7] beta_age;
  matrix[7,2*bend_mean] beta_bend;
  real<lower=0> sigma_process;
  real<lower=0> sigma_visit;
  real<lower=0> ell;
  vector<lower=0,upper=1>[event_kernel] kappa_crack;
  vector<lower=0,upper=1>[event_kernel] kappa_seal;
}
transformed parameters {
  vector[N] mu;
  for (n in 1:N) {
    vector[7] coefficient=beta+beta_age*((age[n]-10)/10);
    if (bend_mean==1)
      coefficient += beta_bend[,1]*fmax(age[n]-knot1,0)/10
                     +beta_bend[,2]*fmax(age[n]-knot2,0)/10;
    mu[n]=alpha[campaign[n]]+X[section[n]]*coefficient;
  }
}
model {
  alpha ~ normal(log(5),1.5);
  beta ~ normal(0,1);
  beta_age ~ normal(0,0.5);
  to_vector(beta_bend) ~ normal(0,0.5);
  sigma_process ~ normal(0,0.5);
  sigma_visit ~ normal(0,0.25);
  ell ~ lognormal(log(ell_median),ell_log_sd);
  kappa_crack ~ beta(kappa_a,kappa_b);
  kappa_seal ~ beta(kappa_a,kappa_b);
  for (g in 1:G) {
    int ng=size[g]; int a=first[g];
    matrix[ng,ng] K;
    for (i in 1:ng) for (j in 1:ng) {
      real correlation=exp(-abs(age[a+i-1]-age[a+j-1])/ell);
      if (event_kernel==1)
        correlation *= pow(kappa_crack[1],abs(crack_count[a+i-1]-crack_count[a+j-1]))
                       *pow(kappa_seal[1],abs(seal_count[a+i-1]-seal_count[a+j-1]));
      K[i,j]=square(sigma_process)*correlation+(i==j ? square(sigma_visit):0);
    }
    if (rounded_likelihood==1)
      segment(log_latent,a,ng) ~ multi_normal_cholesky(segment(mu,a,ng),cholesky_decompose(K));
    else
      segment(log_y,a,ng) ~ multi_normal_cholesky(segment(mu,a,ng),cholesky_decompose(K));
  }
}
generated quantities {
  vector[N] y_rep;
  vector[3] delta_mm=rep_vector(0,3);
  for (g in 1:G) {
    int ng=size[g]; int a=first[g]; matrix[ng,ng] K;
    vector[ng] log_rep;
    for (i in 1:ng) for (j in 1:ng) {
      real correlation=exp(-abs(age[a+i-1]-age[a+j-1])/ell);
      if (event_kernel==1)
        correlation *= pow(kappa_crack[1],abs(crack_count[a+i-1]-crack_count[a+j-1]))
                       *pow(kappa_seal[1],abs(seal_count[a+i-1]-seal_count[a+j-1]));
      K[i,j]=square(sigma_process)*correlation+(i==j ? square(sigma_visit):0);
    }
    log_rep=multi_normal_cholesky_rng(segment(mu,a,ng),cholesky_decompose(K));
    for (i in 1:ng) y_rep[a+i-1]=exp(log_rep[i]);
  }
  for (c in 1:CE) {
    vector[7] coefficient=beta+beta_age*((eval_age[c]-10)/10);
    vector[8] mean_c;
    if (bend_mean==1)
      coefficient += beta_bend[,1]*fmax(eval_age[c]-knot1,0)/10
                     +beta_bend[,2]*fmax(eval_age[c]-knot2,0)/10;
    for (s in 1:8)
      mean_c[s]=exp(alpha[eval_campaign[c]]+X[s]*coefficient
                     +(square(sigma_process)+square(sigma_visit))/2);
    for (k in 1:3) delta_mm[k] += 0.5*dot_product(mean_c,X[,k])/CE;
  }
}
